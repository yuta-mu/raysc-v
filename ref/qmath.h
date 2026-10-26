#include <stdint.h>

static inline int64_t sx32(uint32_t u) {
  return (u <= 0x7FFFFFFFU) ? (int64_t)u : (int64_t)u - INT64_C(4294967296);
}

static inline int64_t floor_div_pow2(int64_t x, unsigned n) { /* n in 0..31 */
  int64_t d = INT64_C(1) << n, q = x / d, r = x % d;
  if (r < 0)
    --q;
  return q;
}

static inline uint32_t q16_mul(uint32_t a, uint32_t b) {
  return (uint32_t)(uint64_t)floor_div_pow2(sx32(a) * sx32(b), 16);
}

static inline uint32_t i32_div(uint32_t a, uint32_t b) {
  if (b == 0U)
    return 0xFFFFFFFFU;
  if (a == 0x80000000U && b == 0xFFFFFFFFU)
    return 0x80000000U;
  return (uint32_t)(int32_t)(sx32(a) / sx32(b));
}

static inline uint32_t i32_rem(uint32_t a, uint32_t b) {
  if (b == 0U)
    return a;
  if (a == 0x80000000U && b == 0xFFFFFFFFU)
    return 0U;
  return (uint32_t)(int32_t)(sx32(a) % sx32(b));
}

static inline uint32_t q16_rcp(uint32_t x_raw) {
  if (x_raw == 0U)
    return 0x7FFFFFFFU;
  const int64_t x = sx32(x_raw), num = INT64_C(1) << 32;
  int64_t q = num / x, r = num % x;
  if (x < 0 && r != 0)
    --q; /* 負の分母の floor 補正 */
  if (q > INT64_C(2147483647))
    return 0x7FFFFFFFU;
  if (q < -INT64_C(2147483648))
    return 0x80000000U;
  return (uint32_t)(int32_t)q;
}

/* floor(sqrt(n)) : n は 0 .. 2^64-1 の全域で正確。浮動小数点を使わないビット単位の筆算法 */
static inline uint32_t isqrt_u64(uint64_t n) {
  uint64_t res = 0, bit = UINT64_C(1) << 62;
  while (bit > n)
    bit >>= 2;
  while (bit != 0) {
    if (n >= res + bit) {
      n -= res + bit;
      res = (res >> 1) + bit;
    } else {
      res >>= 1;
    }
    bit >>= 2;
  }
  return (uint32_t)res;
}

/* sqrt: x <= 0 -> 0,  x > 0 -> floor(sqrt((uint64)x << 16)) (x は raw 値) */
static inline uint32_t q16_sqrt(uint32_t x_raw) {
  const int64_t x = sx32(x_raw);
  if (x <= 0)
    return 0U;
  return isqrt_u64((uint64_t)x << 16);
}

/* rsqrt: x <= 0 -> 0,  x > 0 -> floor(2^24 / sqrt(x)) (x は raw 値) */
static inline uint32_t q16_rsqrt(uint32_t x_raw) {
  const int64_t x = sx32(x_raw);
  if (x <= 0)
    return 0U;
  return isqrt_u64((UINT64_C(1) << 48) / (uint64_t)x);
}

