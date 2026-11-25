let wrap_i64 x = Int64.to_int32 x
let sx32 u = Int64.of_int32 u
let u32_to_i64 x =
  Int64.logand (sx32 x) 0xFFFFFFFFL

(* I *)
let add a b = Int32.add a b
let sub a b = Int32.sub a b
let logxor a b = Int32.logxor a b
let logor a b = Int32.logor a b
let logand a b = Int32.logand a b
let sll a b = Int32.shift_left a (Int32.to_int b land 31)
let srl a b = Int32.shift_right_logical a (Int32.to_int b land 31)
let sra a b = Int32.shift_right a (Int32.to_int b land 31)
let eq a b = if a = b then 1l else 0l
let ne a b = if a <> b then 1l else 0l
let lt a b = if Int32.compare a b < 0 then 1l else 0l
let le a b = if Int32.compare a b <= 0 then 1l else 0l
let gt a b = if Int32.compare a b > 0 then 1l else 0l
let ge a b = if Int32.compare a b >= 0 then 1l else 0l
let ltu a b = if Int32.unsigned_compare a b < 0 then 1l else 0l
let leu a b = if Int32.unsigned_compare a b <= 0 then 1l else 0l
let gtu a b = if Int32.unsigned_compare a b > 0 then 1l else 0l
let geu a b = if Int32.unsigned_compare a b >= 0 then 1l else 0l

let neg a = Int32.neg a
let lognot a = Int32.logxor a 1l

(* Im *)
let mul a b = Int32.mul a b
let mulh a b =
  let p = Int64.mul (sx32 a) (sx32 b) in
  wrap_i64 (Int64.shift_right_logical p 32)
let mulhsu a b =
  let p = Int64.mul (sx32 a) (u32_to_i64 b) in
  wrap_i64 (Int64.shift_right_logical p 32)
let mulhu a b =
  let p = Int64.mul (u32_to_i64 a) (u32_to_i64 b) in
  wrap_i64 (Int64.shift_right_logical p 32)
let div a b =
  if b = 0l then -1l
  else if a = Int32.min_int && b = -1l then Int32.min_int
  else Int32.div a b
let divu a b =
  if b = 0l then -1l else Int32.unsigned_div a b
let rem a b =
  if b = 0l then a
  else if a = Int32.min_int && b = -1l then 0l
  else Int32.rem a b
let remu a b =
  if b = 0l then a else Int32.unsigned_rem a b

(* Im_zbb *)
let andn a b = Int32.logand a (Int32.lognot b)
let orn a b  = Int32.logor a (Int32.lognot b)
let xnor a b = Int32.lognot (Int32.logxor a b)
let max a b = if Int32.compare a b > 0 then a else b
let maxu a b = if Int32.unsigned_compare a b > 0 then a else b
let min a b = if Int32.compare a b < 0 then a else b
let minu a b = if Int32.unsigned_compare a b < 0 then a else b

let clz x =
  if x = 0l then 32l
  else
    let rec loop i mask =
      if Int32.logand x mask <> 0l then i
      else loop (Int32.add i 1l) (Int32.shift_right_logical mask 1)
    in
    loop 0l 0x80000000l
let sext_b a = Int32.shift_right (Int32.shift_left a 24) 24
let sext_h a = Int32.shift_right (Int32.shift_left a 16) 16

(* Math *)
(*
let floor_div_pow2 x n =
  let d = Int64.shift_left 1L n in
  let q = Int64.div x d in
  let r = Int64.rem x d in
  if r < 0L then Int64.sub q 1L else q
*)
let q16_floor_shift16 val_ =
  let q = Int64.div val_ 65536L in
  let r = Int64.rem val_ 65536L in
  let q' = if r < 0L then Int64.sub q 1L else q in
  wrap_i64 q'

let qmul a b =
  let prod = Int64.mul (sx32 a) (sx32 b) in
  q16_floor_shift16 prod

let isqrt n =
  if n <= 0L then 0L
  else
    let rec loop lo hi =
      if Int64.add lo 1L >= hi then lo
      else
        let mid = Int64.div (Int64.add lo hi) 2L in
        if Int64.mul mid mid <= n then loop mid hi else loop lo mid
    in
    loop 0L 4294967296L

let qsqrt x =
  if x <= 0l then 0l
  else
    let n = Int64.shift_left (Int64.logand (sx32 x) 0xFFFFFFFFL) 16 in
    wrap_i64 (isqrt n)

let qrsqrt x =
  if x <= 0l then 0l
  else wrap_i64 (isqrt (Int64.div 281474976710656L (sx32 x)))   (* 281474976710656 = 2^48 *)

let qrcp x_raw =
  if x_raw = 0l then 0x7fffffffl
  else
    let x_val = sx32 x_raw in
    let num = 4294967296L in
    let q = Int64.div num x_val in
    let r = Int64.rem num x_val in
    let q' = if x_val < 0L && r <> 0L then Int64.sub q 1L else q in
    if q' > 2147483647L then 0x7fffffffl
    else if q' < -2147483648L then Int32.min_int
    else wrap_i64 q'

(* parser *)
let parse_i32 s =
  let v = Int64.of_string s in
  wrap_i64 v

let parse_q16 s =
  let dot = String.index s '.' in
  let whole = String.sub s 0 dot in
  let frac = String.sub s (dot + 1) (String.length s - dot - 1) in
  if frac = "" then failwith ("invalid q16 literal: " ^ s);
  let k = String.length frac in
  if k > 18 then
    failwith "q16 literals may contain at most 18 fractional digits";
  let w = Int64.of_string whole in
  let f = Int64.of_string frac in
  let rec pow5 n acc = if n = 0 then acc else pow5 (n - 1) (Int64.mul acc 5L) in
  (* f * 65536 / 10^k, with the powers of two cancelled before multiplying. *)
  let numerator, denominator =
    if k <= 16 then
      (Int64.mul f (Int64.shift_left 1L (16 - k)), pow5 k 1L)
    else
      (f, Int64.mul (pow5 k 1L) (Int64.shift_left 1L (k - 16)))
  in
  let q = Int64.div numerator denominator in
  let r = Int64.rem numerator denominator in
  let twice = Int64.mul r 2L in
  let rounded_frac =
    if twice > denominator ||
       (twice = denominator && Int64.logand q 1L = 1L)
    then Int64.add q 1L else q
  in
  let raw = Int64.add (Int64.mul w 65536L) rounded_frac in
  wrap_i64 raw
