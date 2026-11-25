open Ast

(* translate でどの IR に変換されるか *)
type builtin_kind =
  | B_Binop of Ir.binop
  | B_Unop of Ir.unop
  | B_Cast_q16
  | B_Cast_i32
  | B_Consumer of Ir.cons
  | B_Supplier of Ir.supp
  | B_AccelSetSphere
  | B_AccelHit

(* 組み込み関数の定義レコード *)
type builtin_def = {
  name : string;
  param_types : typ list;
  ret_type : typ;
  kind : builtin_kind;
}

(* 組み込み関数のマスタデータ *)
let all_builtins = [
  (* キャスト *)
  { name = "q16"; param_types = [I32]; ret_type = Q16; kind = B_Cast_q16 };
  { name = "i32"; param_types = [Q16]; ret_type = I32; kind = B_Cast_i32 };

  (* Volatile 命令 *)
  { name = "cycles"; param_types = [];    ret_type = I32; kind = B_Supplier Cycles };
  { name = "bprint"; param_types = [I32]; ret_type = Void;     kind = B_Consumer Bprint };
  { name = "qseed";  param_types = [I32]; ret_type = Void;     kind = B_Consumer Qseed };
  { name = "qrand";  param_types = [];    ret_type = Q16; kind = B_Supplier Qrand };
  { name = "qrands"; param_types = [];    ret_type = Q16; kind = B_Supplier Qrands };

  (* アクセラレータ命令 *)
  { name = "accel_set_sphere"; 
    param_types = [I32; Q16; Q16; Q16; Q16; Q16; I32]; 
    ret_type = Void; 
    kind = B_AccelSetSphere };
  { name = "accel_hit"; 
    param_types = [Q16; Q16; Q16; Q16; Q16; Q16; Q16; Q16]; 
    ret_type = I32; 
    kind = B_AccelHit };
  { name = "accel_t"; 
    param_types = []; 
    ret_type = Q16; 
    kind = B_Supplier AccelT };
]

(* ハードウェア二項演算命令のマスタデータ *)
let hw_binops : (string * Ir.binop) list = [
  ("add",    Add);
  ("sub",    Sub);
  ("xor",    Xor);
  ("or",     Or);
  ("and",    And);
  ("sll",    Sll);
  ("srl",    Srl);
  ("sra",    Sra);
  ("eq",     Eq);
  ("ne",     Ne);
  ("lt",     Lt);
  ("le",     Le);
  ("gt",     Gt);
  ("ge",     Ge);
  ("ltu",    Ltu);
  ("leu",    Leu);
  ("gtu",    Gtu);
  ("geu",    Geu);
  ("mul",    Mul);
  ("mulh",   Mulh);
  ("mulhsu", Mulhsu);
  ("mulhu",  Mulhu);
  ("div",    Div);
  ("divu",   Divu);
  ("rem",    Rem);
  ("remu",   Remu);
  ("andn",   Andn);
  ("orn",    Orn);
  ("xnor",   Xnor);
  ("max",    Max);
  ("maxu",   Maxu);
  ("min",    Min);
  ("minu",   Minu);
  ("qmul",   QMul);
]

(* ハードウェア単項演算命令のマスタデータ *)
let hw_unops : (string * Ir.unop) list = [
  ("neg",    Neg);
  ("not",    Not);
  ("clz",    Clz);
  ("sext_b", Sext_b);
  ("sext_h", Sext_h);
  ("qsqrt",  QSqrt);
  ("qrsqrt", QRsqrt);
  ("qrcp",   QRcp);
]

(* 名前から組み込み関数, ハードウェア命令を検索 *)
let lookup name =
  List.find_opt (fun b -> b.name = name) all_builtins
let lookup_hw_binop name = List.assoc_opt name hw_binops
let lookup_hw_unop  name = List.assoc_opt name hw_unops

(* 標準ライブラリ *)
let stdlib_source = {|
// Math -> Im

fn __qmul(a: q16, b: q16) -> q16 {
    let lo: q16;
    let hi: q16;

    lo = __hw_binop("mul", a, b);
    lo = __hw_binop("srl", lo, 16);
    hi = __hw_binop("mulh", a, b);
    hi = __hw_binop("sll", hi, 16);
    return __hw_binop("or", lo, hi);
}

fn sqrt(a: q16) -> q16 {
    let raw: i32;
    let rem: i32;
    let root: i32;
    let i: i32;
    let bits: i32;
    let trial: i32;

    raw = __any(a);
    if (raw <= 0) { return 0.0; }

    rem = 0;
    root = 0;
    i = 23;
    while (i >= 0) {
        bits = 0;
        if (i >= 8) {
            bits = __hw_binop("srl", raw, (i - 8) << 1) & 3;
        }
        rem = (rem << 2) | bits;
        trial = (root << 2) | 1;
        if (__hw_binop("geu", rem, trial)) {
            rem = rem - trial;
            root = (root << 1) | 1;
        } else {
            root = root << 1;
        }
        i = i - 1;
    }
    return __any(root);
}

fn rsqrt(a: q16) -> q16 {
    let raw: i32;
    let r: i32;
    let q_hi: i32;
    let i: i32;
    let q_lo: i32;
    let j: i32;
    let rem: i32;
    let root: i32;
    let k: i32;
    let bits: i32;
    let trial: i32;

    raw = __any(a);
    if (raw <= 0) { return 0.0; }
    if (raw == 1) { return __any(0x01000000); } // sqrt(2^48) = 2^24

    // Step 1: 48bit 商 quotient = floor(2^48 / raw) を (q_hi: 上位16bit, q_lo: 下位32bit) に計算
    r = 1;
    q_hi = 0;
    i = 15;
    while (i >= 0) {
        r = r << 1;
        if (__hw_binop("geu", r, raw)) {
            r = r - raw;
            q_hi = q_hi | (1 << i);
        }
        i = i - 1;
    }

    q_lo = 0;
    j = 31;
    while (j >= 0) {
        r = r << 1;
        if (__hw_binop("geu", r, raw)) {
            r = r - raw;
            q_lo = q_lo | (1 << j);
        }
        j = j - 1;
    }

    // Step 2: 48bit 値 (q_hi, q_lo) のビット単位開平法 (24回)
    rem = 0;
    root = 0;
    k = 23;
    while (k >= 0) {
        bits = 0;
        if (k >= 16) {
            bits = __hw_binop("srl", q_hi, (k - 16) << 1) & 3;
        } else {
            bits = __hw_binop("srl", q_lo, k << 1) & 3;
        }
        rem = (rem << 2) | bits;
        trial = (root << 2) | 1;
        if (__hw_binop("geu", rem, trial)) {
            rem = rem - trial;
            root = (root << 1) | 1;
        } else {
            root = root << 1;
        }
        k = k - 1;
    }
    return __any(root);
}

fn rcp(a: q16) -> q16 {
    let raw: i32;
    let neg: i32;
    let u: i32;
    let r: i32;
    let q: i32;
    let i: i32;

    raw = __any(a);
    if (raw == 0) { return __any(0x7FFFFFFF); }
    if (raw == 0x80000000) { return __any(-2); }

    neg = 0;
    u = raw;
    if (u < 0) {
        u = -u;
        neg = 1;
    }
    // |a| <= 2 の場合は 32bit 符号付き整数で表現可能な範囲を超えるため飽和
    if (u <= 2) {
        if (neg != 0) { return __any(0x80000000); }
        return __any(0x7FFFFFFF);
    }

    r = 1;
    q = 0;
    i = 31;
    while (i >= 0) {
        r = r << 1;
        if (__hw_binop("geu", r, u)) {
            r = r - u;
            q = q | (1 << i);
        }
        i = i - 1;
    }

    if (neg != 0) { return __any(-q); }
    return __any(q);
}

// Im_zbb -> Im

fn min(a: i32, b: i32) -> i32 {
    if (a < b) { return a; } else { return b; }
}

fn max(a: i32, b: i32) -> i32 {
    if (a > b) { return a; } else { return b; }
}

fn qmin(a: q16, b: q16) -> q16 {
    if (a < b) { return a; } else { return b; }
}

fn qmax(a: q16, b: q16) -> q16 {
    if (a > b) { return a; } else { return b; }
}

fn andn(a: i32, b: i32) -> i32 {
    return a & (b ^ -1);
}

fn orn(a: i32, b: i32) -> i32 {
    return a | (b ^ -1);
}

fn xnor(a: i32, b: i32) -> i32 {
    return (a ^ b) ^ -1;
}

fn clz(x: i32) -> i32 {
    let count: i32;
    let mask: i32;

    if (x == 0) { return -1; }
    count = 0;
    mask = 0x80000000;
    while ((x & mask) == 0) {
        count = count + 1;
        mask = __hw_binop("srl", mask, 1);
    }
    return count;
}

fn qclz(x: q16) -> i32 {
    let raw: i32;
    raw = __any(x);
    return clz(raw);
}

fn qabs(x: q16) -> q16 {
    return qmax(x, -x);
}

fn qclamp(x: q16, min_val: q16, max_val: q16) -> q16 {
    return qmin(qmax(x, min_val), max_val);
}

// Im -> I

fn __mul(a: i32, b: i32) -> i32 {
    let res: i32;
    let multiplier: i32;
    let multiplicand: i32;

    res = 0;
    multiplier = b;
    multiplicand = a;
    while (multiplier != 0) {
        if ((multiplier & 1) != 0) {
            res = res + multiplicand;
        }
        multiplicand = multiplicand << 1;
        multiplier = __hw_binop("srl", multiplier, 1);
    }
    return res;
}

fn __mulhu(a: i32, b: i32) -> i32 {
    let a_lo: i32;
    let a_hi: i32;
    let b_lo: i32;
    let b_hi: i32;
    let p0: i32;
    let p1: i32;
    let p2: i32;
    let p3: i32;
    let mid1: i32;
    let carry1: i32;
    let mid2: i32;
    let carry2: i32;

    a_lo = a & 0xFFFF;
    a_hi = __hw_binop("srl", a, 16);
    b_lo = b & 0xFFFF;
    b_hi = __hw_binop("srl", b, 16);

    p0 = __mul(a_lo, b_lo);
    p1 = __mul(a_lo, b_hi);
    p2 = __mul(a_hi, b_lo);
    p3 = __mul(a_hi, b_hi);

    mid1 = p1 + __hw_binop("srl", p0, 16);
    carry1 = 0;
    if (__hw_binop("ltu", mid1, p1)) { carry1 = 0x10000; }

    mid2 = mid1 + p2;
    carry2 = 0;
    if (__hw_binop("ltu", mid2, mid1)) { carry2 = 0x10000; }

    return p3 + __hw_binop("srl", mid2, 16) + carry1 + carry2;
}

fn __mulh(a: i32, b: i32) -> i32 {
    let hi: i32;

    hi = __mulhu(a, b);
    if (a < 0) { hi = hi - b; }
    if (b < 0) { hi = hi - a; }
    return hi;
}

fn __udiv_rem(n: i32, d: i32, is_rem: i32) -> i32 {
    let q: i32;
    let r: i32;
    let i: i32;

    if (d == 0) {
        if (is_rem != 0) { return n; } else { return -1; }
    }
    q = 0;
    r = 0;
    i = 31;
    while (i >= 0) {
        r = r << 1;
        r = r | (__hw_binop("srl", n, i) & 1);
        if (__hw_binop("geu", r, d)) {
            r = r - d;
            q = q | (1 << i);
        }
        i = i - 1;
    }
    if (is_rem != 0) { return r; } else { return q; }
}

fn __div(a: i32, b: i32) -> i32 {
    let neg: i32;
    let ua: i32;
    let ub: i32;
    let q: i32;

    if (b == 0) { return -1; }
    // INT32_MIN / -1 のオーバーフロー処理
    if (a == 0x80000000 && b == -1) { return 0x80000000; }

    neg = 0;
    ua = a;
    ub = b;
    if (ua < 0) { ua = -ua; neg = neg ^ 1; }
    if (ub < 0) { ub = -ub; neg = neg ^ 1; }

    q = __udiv_rem(ua, ub, 0);
    if (neg != 0) { return -q; } else { return q; }
}

fn __rem(a: i32, b: i32) -> i32 {
    let neg: i32;
    let ua: i32;
    let ub: i32;
    let r: i32;

    if (b == 0) { return a; }
    if (a == 0x80000000 && b == -1) { return 0; }

    neg = 0;
    ua = a;
    ub = b;
    if (ua < 0) { ua = -ua; neg = 1; }
    if (ub < 0) { ub = -ub; }

    r = __udiv_rem(ua, ub, 1);
    if (neg != 0) { return -r; } else { return r; }
}
|}
