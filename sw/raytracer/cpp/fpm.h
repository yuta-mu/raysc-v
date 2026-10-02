#ifndef FPM_H
#define FPM_H

#include <cstdint>

using fpm_t = int32_t;

constexpr int f_frac_bits = 16;
constexpr fpm_t f_scale = 1 << f_frac_bits;

fpm_t fpm_from_int(int32_t value);
int fpm_to_int(fpm_t value);
fpm_t fpm_add(fpm_t a, fpm_t b);
fpm_t fpm_sub(fpm_t a, fpm_t b);
fpm_t fpm_mul(fpm_t a, fpm_t b);
fpm_t fpm_div(fpm_t a, fpm_t b);
fpm_t fpm_sqrt(fpm_t a);
fpm_t fpm_from_ratio(int32_t numerator, int32_t denominator);

#endif