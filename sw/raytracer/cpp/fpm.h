#ifndef FPM_H
#define FPM_H

#include <cstdint>

using fpm_t = int32_t;

constexpr int f_frac_bits = 16;
constexpr fpm_t f_scale = 1 << f_frac_bits;
constexpr fpm_t f_pi = 205887;

fpm_t fpm_mul(fpm_t a, fpm_t b);
fpm_t fpm_div(fpm_t a, fpm_t b);
fpm_t fpm_sqrt(fpm_t a);

fpm_t fpm_tan(fpm_t angle);
fpm_t fpm_sin(fpm_t angle);
fpm_t fpm_cos(fpm_t angle);
fpm_t fpm_atan2(fpm_t y, fpm_t x);
fpm_t fpm_asin(fpm_t value);
fpm_t fpm_log(fpm_t value);
fpm_t fpm_div_clamped(fpm_t a, fpm_t b);

inline fpm_t fpm_from_ratio(int32_t numerator, int32_t denominator) {
    return fpm_div(numerator, denominator);
}

#endif
