#ifndef QMATH_H
#define QMATH_H

#include <stdint.h>

/* =====================================================================
 * RaySC-V Q16.16 & Math Library (Golden Model)
 *
 * 外部関数 (libgcc の __divdi3 / __udivdi3 / __moddi3 / __muldi3 など) を呼ばない実装。
 * ===================================================================== */

static inline int64_t sx32(uint32_t u) {
  return (u <= 0x7FFFFFFFU) ? (int64_t)u : (int64_t)u - INT64_C(4294967296);
}

static inline int32_t sx32i(uint32_t u) {
  return (u <= 0x7FFFFFFFU) ? (int32_t)u
                            : (int32_t)(u - 0x80000000U) - INT32_C(2147483647) - 1;
}

static inline uint64_t shr_u64(uint64_t v, unsigned n) {
  const uint32_t lo = (uint32_t)v, hi = (uint32_t)(v >> 32);
  if (n == 0U) return v;
  return ((uint64_t)(hi >> n) << 32) | (uint32_t)((lo >> n) | (hi << (32U - n)));
}

static inline int64_t floor_div_pow2(int64_t x, unsigned n) {
  return (x >= 0) ? (int64_t)shr_u64((uint64_t)x, n) : ~(int64_t)shr_u64((uint64_t)~x, n);
}

static inline uint64_t mul_u32(uint32_t a, uint32_t b) { 
  return (uint64_t)a * b; 
}

/* =====================================================================
 * ベース演算
 * ===================================================================== */

static inline uint32_t q16_mul(uint32_t a, uint32_t b) {
  return (uint32_t)(uint64_t)floor_div_pow2(sx32(a) * sx32(b), 16);
}

static inline uint32_t i32_div(uint32_t a, uint32_t b) {
  if (b == 0U) return 0xFFFFFFFFU;
  if (a == 0x80000000U && b == 0xFFFFFFFFU) return 0x80000000U;
  return (uint32_t)(sx32i(a) / sx32i(b)); 
}

static inline uint32_t i32_rem(uint32_t a, uint32_t b) {
  if (b == 0U) return a;
  if (a == 0x80000000U && b == 0xFFFFFFFFU) return 0U;
  return (uint32_t)(sx32i(a) % sx32i(b)); 
}

/* 絶対値: Q16.16 / 32bit整数 共通。INT_MIN (0x80000000) はオーバーフローして自身に戻る仕様 */
static inline uint32_t i32_abs(uint32_t a_raw) {
  int32_t a = sx32i(a_raw);
  return (uint32_t)(a < 0 ? -a : a);
}

/* =====================================================================
 * 高度な数学・カスタム命令対応 (Feature level 2 & 3)
 * ===================================================================== */

static inline uint32_t q16_rcp(uint32_t x_raw) {
  if (x_raw == 0U) return 0x7FFFFFFFU;
  if (x_raw <= 0x7FFFFFFFU) {
    if (x_raw <= 2U) return 0x7FFFFFFFU;
    return (0U - x_raw) / x_raw + 1U; 
  } else {
    const uint32_t m = 0U - x_raw; 
    if (m <= 2U) return 0x80000000U;
    return 0U - (0xFFFFFFFFU / m + 1U); 
  }
}

static inline uint32_t isqrt_u64(uint64_t n) {
  uint64_t res = 0, bit = UINT64_C(1) << 62;
  while (bit > n) bit >>= 2;
  while (bit != 0) {
    if (n >= res + bit) { n -= res + bit; res = (res >> 1) + bit; }
    else { res >>= 1; }
    bit >>= 2;
  }
  return (uint32_t)res;
}

static inline uint32_t q16_sqrt(uint32_t x_raw) {
  const int64_t x = sx32(x_raw);
  if (x <= 0) return 0U;
  return isqrt_u64((uint64_t)x << 16);
}

/* rsqrt: x <= 0 -> 0,  x > 0 -> floor(2^24 / sqrt(x))
 * 村上さんの仕様に準拠: 途中で sqrt を切り捨てない厳密な計算 */
static inline uint32_t q16_rsqrt(uint32_t x_raw) {
  uint32_t r = 0U;
  if (x_raw == 0U || x_raw > 0x7FFFFFFFU) return 0U;
  for (uint32_t bit = UINT32_C(1) << 24; bit != 0U; bit >>= 1) {
    const uint32_t c = r | bit;
    const uint64_t sq = mul_u32(c, c);
    const uint64_t a = mul_u32((uint32_t)(sq >> 32), x_raw);
    const uint64_t b = mul_u32((uint32_t)sq, x_raw);
    const uint64_t high = a + (b >> 32);
    if (high < UINT64_C(0x10000) || (high == UINT64_C(0x10000) && (uint32_t)b == 0U))
      r = c;
  }
  return r;
}

static inline uint32_t q16_dot3(uint32_t ax, uint32_t ay, uint32_t az,
                                uint32_t bx, uint32_t by, uint32_t bz) {
  int32_t dx = (int32_t)q16_mul(ax, bx);
  int32_t dy = (int32_t)q16_mul(ay, by);
  int32_t dz = (int32_t)q16_mul(az, bz);
  return (uint32_t)(dx + dy + dz);
}

#endif // QMATH_H
