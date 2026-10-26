#include <stdio.h>
#include <assert.h>
#include <stdint.h>
#include "ver2_qmath.h" // ← ここを修正しました

// ==========================================
// 単体テスト群 (付録の検証項目及び Golden Model に準拠)
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
    assert(floor_div_pow2(100LL, 0) == 100LL);
    assert(floor_div_pow2(-100LL, 0) == -100LL);
    int64_t large_pos = INT64_C(1) << 31;
    assert(floor_div_pow2(large_pos, 31) == 1LL);
    assert(floor_div_pow2(-5LL, 1) == -3LL);
    assert(floor_div_pow2(-4LL, 1) == -2LL);
}

// 3. q16_mul のテスト (Golden Model 準拠)
void test_q16_mul(void) {
    assert(q16_mul(0x80000000U, 0x80000000U) == 0x00000000U);
    assert(q16_mul(0xFFFFFFFFU, 0x00000001U) == 0xFFFFFFFFU);
    assert(q16_mul(0xFFFFFFFFU, 0xFFFFFFFFU) == 0x00000000U);
    assert(q16_mul(0x00000000U, 0x00000000U) == 0x00000000U);
    assert(q16_mul(0x7FFFFFFFU, 0x7FFFFFFFU) == 0xFFFF0000U);
    assert(q16_mul(0x00010000U, 0x00010000U) == 0x00010000U);
}

// 4. i32_div / i32_rem の特異値・境界値テスト (Golden Model 準拠)
void test_i32_div_rem(void) {
    assert(i32_div(0x0000000AU, 0x00000000U) == 0xFFFFFFFFU);
    assert(i32_rem(0x0000000AU, 0x00000000U) == 0x0000000AU);
    
    assert(i32_div(0x80000000U, 0xFFFFFFFFU) == 0x80000000U);
    assert(i32_rem(0x80000000U, 0xFFFFFFFFU) == 0x00000000U);
    
    assert(i32_div(0xFFFFFFF6U, 0xFFFFFFFDU) == 0x00000003U);
    assert(i32_rem(0xFFFFFFF6U, 0xFFFFFFFDU) == 0xFFFFFFFFU);
    
    assert(i32_div(0xFFFFFFF6U, 0x00000003U) == 0xFFFFFFFDU);
    assert(i32_rem(0xFFFFFFF6U, 0x00000003U) == 0xFFFFFFFFU);
    
    assert(i32_div(0x7FFFFFFFU, 0x00000002U) == 0x3FFFFFFFU);
    assert(i32_rem(0x7FFFFFFFU, 0x00000002U) == 0x00000001U);
}

// 5. q16_rcp のテスト (Golden Model 準拠)
void test_q16_rcp(void) {
    assert(q16_rcp(0x00000000U) == 0x7FFFFFFFU);
    assert(q16_rcp(0x00000001U) == 0x7FFFFFFFU);
    assert(q16_rcp(0xFFFFFFFFU) == 0x80000000U);
    assert(q16_rcp(0x00000002U) == 0x7FFFFFFFU);
    assert(q16_rcp(0xFFFFFFFEU) == 0x80000000U);
    assert(q16_rcp(0x80000000U) == 0xFFFFFFFEU);
    assert(q16_rcp(0xFFFF0000U) == 0xFFFF0000U); // -1.0 -> -1.0
    assert(q16_rcp(0x7FFFFFFFU) == 0x00000002U);
}

// 6. q16_sqrt のテスト (Golden Model 準拠)
void test_q16_sqrt(void) {
    assert(q16_sqrt(0x80000000U) == 0x00000000U); // 負数は0
    assert(q16_sqrt(0xFFFF0000U) == 0x00000000U);
    assert(q16_sqrt(0x00000000U) == 0x00000000U);
    assert(q16_sqrt(0x00000001U) == 0x00000100U);
    assert(q16_sqrt(0x00000002U) == 0x0000016AU);
    assert(q16_sqrt(0x0000FE00U) == 0x0000FEFFU);
    assert(q16_sqrt(0x00010000U) == 0x00010000U); // 1.0 -> 1.0
    assert(q16_sqrt(0x7FFFFFFFU) == 0x00B504F3U);
}

// 7. q16_rsqrt のテスト (Golden Model: floor(2^24 / sqrt(x)) 準拠)
void test_q16_rsqrt(void) {
    assert(q16_rsqrt(0x80000000U) == 0x00000000U); // 負数は0
    assert(q16_rsqrt(0xFFFF0000U) == 0x00000000U);
    assert(q16_rsqrt(0x00000000U) == 0x00000000U);
    assert(q16_rsqrt(0x00000001U) == 0x01000000U);
    assert(q16_rsqrt(0x00000002U) == 0x00B504F3U);
    assert(q16_rsqrt(0x00000004U) == 0x00800000U);
    assert(q16_rsqrt(0x0000FE00U) == 0x00010101U);
    assert(q16_rsqrt(0x00010000U) == 0x00010000U); // 1.0 -> 1.0
    assert(q16_rsqrt(0x00010001U) == 0x0000FFFFU);
    assert(q16_rsqrt(0x7FFFFFFFU) == 0x0000016AU);
}

// 8. q16_dot3 のテスト (Golden Model 準拠)
void test_q16_dot3(void) {
    assert(q16_dot3(0x7FFFFFFFU, 0x7FFFFFFFU, 0x7FFFFFFFU, 
                    0x00000001U, 0x00000001U, 0x00000001U) == 0x00017FFDU);
                    
    assert(q16_dot3(0x00010000U, 0x00020000U, 0x00030000U, 
                    0x00010000U, 0x00020000U, 0x00030000U) == 0x000E0000U);
                    
    assert(q16_dot3(0xFFFF0000U, 0xFFFE0000U, 0x00030000U, 
                    0x00010000U, 0xFFFE0000U, 0x00030000U) == 0x000C0000U);
}

// 9. i32_abs のテスト (Golden Model 準拠)
void test_i32_abs(void) {
    assert(i32_abs(0x00000000U) == 0x00000000U);
    assert(i32_abs(0x00000001U) == 0x00000001U);
    assert(i32_abs(0xFFFFFFFFU) == 0x00000001U); // -1 -> 1
    assert(i32_abs(0x7FFFFFFFU) == 0x7FFFFFFFU); // INT_MAX -> INT_MAX
    assert(i32_abs(0x80000000U) == 0x80000000U); // INT_MIN -> ラップアラウンドして INT_MIN
}

// ==========================================
// メイン関数
// ==========================================
int main(void) {
    printf("=== RayQ Math Library Unit Tests (v2) ===\n");
    
    test_sx32();
    test_floor_div_pow2();
    printf("[PASS] Base Helper functions (sx32, floor_div_pow2)\n");

    test_q16_mul();
    printf("[PASS] q16_mul tests\n");

    test_i32_div_rem();
    printf("[PASS] i32_div & i32_rem tests\n");

    test_i32_abs();
    printf("[PASS] i32_abs tests\n");

    test_q16_rcp();
    printf("[PASS] q16_rcp tests\n");

    test_q16_sqrt();
    printf("[PASS] q16_sqrt tests\n");

    test_q16_rsqrt();
    printf("[PASS] q16_rsqrt tests\n");

    test_q16_dot3();
    printf("[PASS] q16_dot3 tests\n");

    printf("\nAll unit tests passed successfully!\n");
    return 0;
}