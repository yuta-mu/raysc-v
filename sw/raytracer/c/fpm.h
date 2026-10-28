#ifndef FPM_H
#define FPM_H

#include <stdint.h>

typedef int32_t fpm_t;

enum {
    f_frac_bits = 16,
    f_scale = 1 << f_frac_bits,
    f_pi = 205887
};

fpm_t fpm_mul(fpm_t a, fpm_t b);
fpm_t fpm_div(fpm_t a, fpm_t b);
fpm_t fpm_sqrt(fpm_t a);

fpm_t fpm_tan(fpm_t angle);
fpm_t fpm_rcp(fpm_t x);
fpm_t fpm_rsqrt(fpm_t x);

static inline fpm_t fpm_from_ratio(int32_t numerator, int32_t denominator) {
    return fpm_div(numerator, denominator);
}

static inline fpm_t fpm_add(fpm_t a, fpm_t b){
    const uint32_t sum = (uint32_t)a + (uint32_t)b;
    if (sum <= INT32_MAX) {
        return (fpm_t)sum;
    }
    else {
        return -1 - (fpm_t)(UINT32_MAX - sum);
    }
}

static inline fpm_t fpm_sub(fpm_t a, fpm_t b){
    const uint32_t diff = (uint32_t)a - (uint32_t)b;
    if (diff <= INT32_MAX) {
        return (fpm_t)diff;
    }
    else {
        return -1 - (fpm_t)(UINT32_MAX - diff);
    }
}

#endif
