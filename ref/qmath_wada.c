#include <stdint.h>

/* 外部関数 (libgcc の __divdi3 / __udivdi3 / __moddi3 / __muldi3 など) を呼ばない実装。
 * 64bit の除算・剰余は使わず、32bit 同士の除算 (rv32im の div/divu/rem)、32x32->64 の乗算
 * (mul + mulhu)、シフト、加減算、比較だけで書く。
 * 注意: コンパイラの最適化 (-O1 以上) を前提とする。-O0 では 64bit の乗算が __muldi3 を呼ぶことがある。 */

static inline int64_t sx32(uint32_t u) {
  return (u <= 0x7FFFFFFFU) ? (int64_t)u : (int64_t)u - INT64_C(4294967296);
}

/* sx32 の int32_t 版 (実装定義の符号付き変換に頼らない) */
static inline int32_t sx32i(uint32_t u) {
  return (u <= 0x7FFFFFFFU) ? (int32_t)u
                            : (int32_t)(u - 0x80000000U) - INT32_C(2147483647) - 1;
}

/* v >> n (論理シフト)。n は 0..31。32bit 同士のシフトだけで書く (64bit の可変シフトを避ける) */
static inline uint64_t shr_u64(uint64_t v, unsigned n) {
  const uint32_t lo = (uint32_t)v, hi = (uint32_t)(v >> 32);
  if (n == 0U)
    return v;
  return ((uint64_t)(hi >> n) << 32) | (uint32_t)((lo >> n) | (hi << (32U - n)));
}

/* floor(x / 2^n), n は 0..31。除算の代わりにシフトを使う。
 * x < 0 のとき m = ~x = -x - 1 (>= 0) として floor(x / 2^n) = ~(m >> n) */
static inline int64_t floor_div_pow2(int64_t x, unsigned n) {
  return (x >= 0) ? (int64_t)shr_u64((uint64_t)x, n) : ~(int64_t)shr_u64((uint64_t)~x, n);
}

static inline uint32_t q16_mul(uint32_t a, uint32_t b) {
  return (uint32_t)(uint64_t)floor_div_pow2(sx32(a) * sx32(b), 16);
}

static inline uint32_t i32_div(uint32_t a, uint32_t b) {
  if (b == 0U)
    return 0xFFFFFFFFU;
  if (a == 0x80000000U && b == 0xFFFFFFFFU)
    return 0x80000000U;
  return (uint32_t)(sx32i(a) / sx32i(b)); /* 32bit の div (0 への丸め) */
}

static inline uint32_t i32_rem(uint32_t a, uint32_t b) {
  if (b == 0U)
    return a;
  if (a == 0x80000000U && b == 0xFFFFFFFFU)
    return 0U;
  return (uint32_t)(sx32i(a) % sx32i(b)); /* 32bit の rem */
}

/* rcp: floor(2^32 / x) を int32 に飽和 (x = 0 は 0x7FFFFFFF)。32bit の divu だけで求める */
static inline uint32_t q16_rcp(uint32_t x_raw) {
  if (x_raw == 0U)
    return 0x7FFFFFFFU;
  if (x_raw <= 0x7FFFFFFFU) {      /* x > 0 */
    if (x_raw <= 2U)               /* 2^32 / x >= 2^31 : 上側に飽和 */
      return 0x7FFFFFFFU;
    return (0U - x_raw) / x_raw + 1U; /* 2^32 = x + (2^32 - x) より floor(2^32/x) = (2^32-x)/x + 1 */
  } else {                         /* x < 0 : m = -x として floor(-2^32/m) = -ceil(2^32/m) */
    const uint32_t m = 0U - x_raw; /* 1 .. 2^31 */
    if (m <= 2U)                   /* m = 1 : 下側に飽和、m = 2 : ちょうど INT_MIN */
      return 0x80000000U;
    return 0U - (0xFFFFFFFFU / m + 1U); /* ceil(2^32/m) = floor((2^32-1)/m) + 1 */
  }
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

/* 32bit x 32bit -> 64bit (rv32im では mul + mulhu) */
static inline uint64_t mul_u32(uint32_t a, uint32_t b) { return (uint64_t)a * b; }

/* rsqrt: x <= 0 -> 0,  x > 0 -> floor(2^24 / sqrt(x)) (x は raw 値)
 *   r <= 2^24 / sqrt(x)  <=>  r^2 * x <= 2^48 を満たす最大の r を、上位ビットから順に決める (25 回)。
 *   c^2 * x は 96bit になるので、32x32->64 の乗算 3 回で求める:
 *     c^2 = sq (64bit),  A = (sq >> 32) * x,  B = (uint32)sq * x,  c^2 * x = A * 2^32 + B
 *     high = A + (B >> 32) = floor(c^2 * x / 2^32)  (< 2^50 で 64bit に収まる)
 *     c^2 * x <= 2^48  <=>  high < 2^16  または  (high == 2^16 かつ (uint32)B == 0)
 *   注意: 仕様書 §9 の rsqrt = rcp(sqrt(x)) とは別の定義 (途中で sqrt を切り捨てない) */
static inline uint32_t q16_rsqrt(uint32_t x_raw) {
  uint32_t r = 0U;
  if (x_raw == 0U || x_raw > 0x7FFFFFFFU) /* x <= 0 */
    return 0U;
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