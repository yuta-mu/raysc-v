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
