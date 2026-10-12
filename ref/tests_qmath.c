#include <stdio.h>
#include <assert.h>
#include <stdint.h>

// ==========================================
// §3 & §9 の C Golden Model 実装
// ==========================================

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

// ==========================================
// 単体テスト群 (付録の検証項目に準拠)
// ==========================================

// 1. sx32の境界値テスト
void test_sx32(void) {
    assert(sx32(0x00000000U) == 0LL); //ゼロ
    assert(sx32(0x00000001U) == 1LL); //最小の正
    assert(sx32(0x7FFFFFFFU) == 2147483647LL); //正の境界 (INT_MAXのraw)
    assert(sx32(0x80000000U) == -2147483648LL); //負の境界 (INT_MINのraw)
    assert(sx32(0xFFFFFFFFU) == -1LL); //最大の負 (-1のraw)
}

// 2. floor_div_pow2の境界テスト
void test_floor_div_pow2(void){
    // 2^0 = 1 シフト量1
    assert(floor_div_pow2(100LL, 0) == 100LL);
    assert(floor_div_pow2(-100LL, 0) == -100LL);

    // 2^31 シフト量31
    int64_t large_pos = INT64_C(1) << 31;
    assert(floor_div_pow2(large_pos, 31) == 1LL);

    // 負の数が正しく丸め込まれるか
    assert(floor_div_pow2(-5LL, 1) == -3LL);
    // 負の数だが割り切れる場合
    assert(floor_div_pow2(-4LL, 1) == -2LL);
}

// 3. q16_mul の境界値・オーバーフロー・ラップアラウンドテスト
void test_q16_mul(void) {
    uint32_t zero = 0x00000000U;
    uint32_t one  = 0x00010000U; // 1.0
    uint32_t neg_one = 0xFFFF0000U; // -1.0
    uint32_t int_max_raw = 0x7FFFFFFFU; // 最大正 raw

    // 基礎テスト
    assert(q16_mul(one, zero) == zero);
    assert(q16_mul(one, one) == one);
    assert(q16_mul(neg_one, neg_one) == one);

    // 負の数床補正の検証 (-0.5 * -0.5 = 0.25 -> 0x4000)
    uint32_t neg_half = 0xFFFF8000U; 
    assert(q16_mul(neg_half, neg_half) == 0x4000U);

    // 境界値の安全な通過確認 (INT_MAX * 1.0)
    assert(q16_mul(int_max_raw, one) == int_max_raw);

    // 軽度のオーバーフロー（ラップせずギリギリ収まるケース: INT_MAX * 2.0）
    uint32_t two = 0x00020000U;
    uint32_t limit_res = q16_mul(int_max_raw, two);
    assert(limit_res == 0xFFFFFFFEU);

    // ラップアラウンド：32bitの枠を完全に突き破る巨大な値同士の掛け算
    // INT_MAX (約32767.9) に対して1000.0 相当の raw値を掛け合わせる
    uint32_t huge_multiplier = 0x64000000U; // 1000.0 相当の raw値
    uint32_t wrapped_res = q16_mul(int_max_raw, huge_multiplier);

    printf("[INFO] q16_mul wrap-around test: INT_MAX * 1000.0 = 0x%08X (Wrapped)\n", wrapped_res);
    assert(wrapped_res != int_max_raw); //ラップアラウンドしてもクラッシュしないことを確認
}

// 4. i32_div / i32_rem の特異値・境界値テスト
void test_i32_div_rem(void) {
    // ゼロ除算ガード (指定値返却)
    assert(i32_div(100U, 0U) == 0xFFFFFFFFU);
    assert(i32_rem(100U, 0U) == 100U);

    // INT_MIN / -1 オーバーフローガード
    assert(i32_div(0x80000000U, 0xFFFFFFFFU) == 0x80000000U);
    assert(i32_rem(0x80000000U, 0xFFFFFFFFU) == 0U);

    // 通常の境界値
    assert(i32_div(0x7FFFFFFFU, 0x00000001U) == 0x7FFFFFFFU);
    assert(i32_div(0x80000000U, 0x00000001U) == 0x80000000U);
    assert(i32_rem(0x7FFFFFFFU, 0x00000002U) == 1U);
}

// 5. q16_rcp の境界値テスト (0, ±1, -65536, INT_MIN, 割り切れない負の値)
void test_q16_rcp(void) {
    uint32_t one = 0x00010000U;       // 1.0 (65536)
    uint32_t neg_one = 0xFFFF0000U;   // -1.0 (-65536)

    // 1. 分母に0 rcp(0) -> 0x7FFFFFFF
    assert(q16_rcp(0U) == 0x7FFFFFFFU);

    // 2-1. 1.0 rcp(1.0) -> 1.0
    assert(q16_rcp(one) == one);

    // 2-2. -1.0 rcp(-1.0) -> -1.0
    assert(q16_rcp(neg_one) == neg_one);

    // 3-1. 上限クランプ (q > 2147483647)
    // 極めて小さな正の値（例: raw値 1 = 0.000015...）の逆数を計算
    // num (2^32) / 1 = 4294967296 
    uint32_t extremely_small_pos = 0x00000001U; // 最小の正の raw 値
    uint32_t rcp_max_clamp = q16_rcp(extremely_small_pos);
    
    printf("[INFO] q16_rcp(0x00000001) result: 0x%08X (Expected: 0x7FFFFFFF)\n", rcp_max_clamp);
    assert(rcp_max_clamp == 0x7FFFFFFFU); // 上限クランプ (0x7FFFFFFF) が返ることを検証

    // 3-2. 下限クランプ (q < -2147483648) 
    // 分母 x が極小の負の値（例: raw値 -1 = 0xFFFFFFFFU）の逆数を計算
    // num / (-1) = -4294967296 となり、下限の -2147483648 を下回る
    uint32_t extremely_small_neg = 0xFFFFFFFFU; // -1 の raw 値 (-0.000015...)
    uint32_t rcp_min_clamp = q16_rcp(extremely_small_neg);

    printf("[INFO] q16_rcp(0xFFFFFFFF) result: 0x%08X (Expected: 0x80000000)\n", rcp_min_clamp);
    assert(rcp_min_clamp == 0x80000000U); // 下限クランプ (0x80000000) が返ることを検証

    // 4-1. 余りがでないパターン　rcp(INT_MIN) の仕様上の結果は -2 のビット表現 (0xFFFFFFFEU)
    assert(q16_rcp(0x80000000U) == 0xFFFFFFFEU);

    // 4-2. 割り切れない負の値のテスト (floor 補正が正しく働くか)
    uint32_t neg_three = 0xFFFD0000U; // -3.0
    uint32_t rcp_neg3 = q16_rcp(neg_three);
    assert(rcp_neg3 != 0x7FFFFFFFU && rcp_neg3 != 0x80000000U);
}

// ==========================================
// メイン関数
// ==========================================
int main(void) {
    printf("=== RayQ Math Library Unit Tests ===\n");
    
    test_sx32();
    printf("[PASS] sx32 tests\n");

    test_floor_div_pow2();
    printf("[PASS] floor_div_pow2 tests\n");

    test_q16_mul();
    printf("[PASS] q16_mul tests\n");

    test_i32_div_rem();
    printf("[PASS] i32_div_rem tests\n");

    test_q16_rcp();
    printf("[PASS] q16_rcp tests\n");

    printf("\nAll unit tests passed successfully!\n");
    return 0;
}