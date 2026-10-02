#ifndef FPM_H
#define FPM_H

#include <cstdint>

using fpm_t = int32_t;

constexpr int f_frac_bits = 16;
constexpr fpm_t f_scale = 1 << f_frac_bits;

// 加減算は保存値の + / -、整数定数は n * f_scale で表す。
// 前提: 結果は int32_t の範囲内、除数は非ゼロ、平方根の入力は非負。
// 乗除算は0方向、平方根は小さい方に丸める。
fpm_t fpm_mul(fpm_t a, fpm_t b);
fpm_t fpm_div(fpm_t a, fpm_t b);
fpm_t fpm_sqrt(fpm_t a);

// 通常の整数の分数を Q16.16 にする。計算式は fpm_div と同じ。
inline fpm_t fpm_from_ratio(int32_t numerator, int32_t denominator) {
    return fpm_div(numerator, denominator);
}

#endif
