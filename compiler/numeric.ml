open Ast

let wrap_i64 x = Int64.to_int32 x

let i32_div a b =
  if b = 0l then -1l
  else if a = Int32.min_int && b = -1l then Int32.min_int
  else Int32.div a b

let i32_rem a b =
  if b = 0l then a
  else if a = Int32.min_int && b = -1l then 0l
  else Int32.rem a b

let floor_div_pow2 x n =
  let d = Int64.shift_left 1L n in
  let q = Int64.div x d in
  let r = Int64.rem x d in
  if r < 0L then Int64.sub q 1L else q

let q16_floor_shift16 val_ =
  let q = Int64.div val_ 65536L in
  let r = Int64.rem val_ 65536L in
  let q' = if r < 0L then Int64.sub q 1L else q in
  wrap_i64 q'

let sx32 u = Int64.of_int32 u

let qmul a b =
  let prod = Int64.mul (sx32 a) (sx32 b) in
  q16_floor_shift16 prod

let q16_rcp x_raw =
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
    let n = Int64.shift_left (Int64.logand (Int64.of_int32 x) 0xFFFFFFFFL) 16 in
    wrap_i64 (isqrt n)

let qrsqrt x = if x <= 0l then 0l else q16_rcp (qsqrt x)

let parse_i32 s =
  let v = Int64.of_string s in
  Int64.to_int32 v

let parse_q16 s =
  let dot = String.index s '.' in
  let whole = String.sub s 0 dot in
  let frac = String.sub s (dot + 1) (String.length s - dot - 1) in
  let w = Int64.of_string whole in
  let f = Int64.of_string frac in
  let rec pow10 n acc = if n = 0 then acc else pow10 (n - 1) (Int64.mul acc 10L) in
  let den = pow10 (String.length frac) 1L in
  let scaled_frac = Int64.mul f 65536L in
  let q = Int64.div scaled_frac den in
  let r = Int64.rem scaled_frac den in
  let twice = Int64.mul r 2L in
  let rounded_frac =
    if twice > den || (twice = den && Int64.logand q 1L = 1L) then Int64.add q 1L else q
  in
  let raw = Int64.add (Int64.mul w 65536L) rounded_frac in
  Int64.to_int32 raw

