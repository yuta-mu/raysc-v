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

  (* Im -> I で使用する命令 *)
  { name = "srl"; param_types = [I32; I32]; ret_type = I32; kind = B_Binop Srl };
  { name = "qsrl"; param_types = [Q16; I32]; ret_type = Q16; kind = B_Binop Srl };
  { name = "ltu"; param_types = [I32; I32]; ret_type = I32; kind = B_Binop Ltu };
  { name = "geu"; param_types = [I32; I32]; ret_type = I32; kind = B_Binop Geu };

  (* Math *)
  { name = "sqrt";  param_types = [Q16]; ret_type = Q16; kind = B_Unop Sqrt };
  { name = "rsqrt"; param_types = [Q16]; ret_type = Q16; kind = B_Unop Rsqrt };
  { name = "rcp";   param_types = [Q16]; ret_type = Q16; kind = B_Unop Rcp };

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

(* 名前から組み込み関数を検索 *)
let lookup name =
  List.find_opt (fun b -> b.name = name) all_builtins

(* 標準ライブラリ *)
let stdlib_source = {|
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

fn minu(a: i32, b: i32) -> i32 {
    if (ltu(a, b) != 0) { return a; } else { return b; }
}

fn maxu(a: i32, b: i32) -> i32 {
    if (ltu(b, a) != 0) { return a; } else { return b; }
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
        mask = srl(mask, 1);
    }
    return count;
}

fn qclz(x: q16) -> i32 {
    let count: i32;
    let mask: q16;

    if (x == 0.0) { return -1; }
    count = 0;
    mask = q16(0x80000000);
    while ((x & mask) == 0.0) {
        count = count + 1;
        mask = qsrl(mask, 1);
    }
    return count;
}

fn sext_b(a: i32) -> i32 {
    return (a << 24) >> 24;
}

fn sext_h(a: i32) -> i32 {
    return (a << 16) >> 16;
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
        multiplier = srl(multiplier, 1);
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
    a_hi = srl(a, 16);
    b_lo = b & 0xFFFF;
    b_hi = srl(b, 16);

    p0 = __mul(a_lo, b_lo);
    p1 = __mul(a_lo, b_hi);
    p2 = __mul(a_hi, b_lo);
    p3 = __mul(a_hi, b_hi);

    mid1 = p1 + srl(p0, 16);
    carry1 = 0;
    if (ltu(mid1, p1) != 0) { carry1 = 0x10000; }

    mid2 = mid1 + p2;
    carry2 = 0;
    if (ltu(mid2, mid1) != 0) { carry2 = 0x10000; }

    return p3 + srl(mid2, 16) + carry1 + carry2;
}

fn __mulh(a: i32, b: i32) -> i32 {
    let hi: i32;

    hi = __mulhu(a, b);
    if (a < 0) { hi = hi - b; }
    if (b < 0) { hi = hi - a; }
    return hi;
}

fn __qmul(a: i32, b: i32) -> i32 {
    let lo: i32;
    let hi: i32;

    lo = __mul(a, b);
    hi = __mulh(a, b);
    return srl(lo, 16) | (hi << 16);
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
        r = r | (srl(n, i) & 1);
        if (geu(r, d) != 0) {
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
