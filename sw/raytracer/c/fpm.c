#include "fpm.h"
#include "qmath.h"
#include <stdbool.h>

static inline uint32_t magnitude(fpm_t value) {
    const uint32_t bits = (uint32_t)value;
    return value < 0 ? 0u - bits : bits;
}

static inline fpm_t with_sign(uint32_t value, bool negative) {
    const uint32_t bits = negative ? 0u - value : value;
    if (bits <= INT32_MAX) {
        return (fpm_t)(bits);
    }
    return -1 - (fpm_t)(UINT32_MAX - bits);
}

fpm_t fpm_mul(fpm_t a, fpm_t b) {
    return with_sign(q16_mul((uint32_t)a, (uint32_t)b), false);
}

fpm_t fpm_div(fpm_t a, fpm_t b) {
    const uint32_t numerator = magnitude(a);
    const uint32_t denominator = magnitude(b);
    if (numerator == 0) {
        return 0;
    }
    if ((denominator & (denominator - 1u)) == 0) {
        int shift = 0;
        for (uint32_t divisor = denominator; divisor > 1; divisor >>= 1) {
            ++shift;
        }
        const uint32_t quotient = shift >= f_frac_bits
            ? numerator >> (shift - f_frac_bits)
            : numerator << (f_frac_bits - shift);
        return with_sign(quotient, (a < 0) != (b < 0));
    }
    uint32_t quotient = 0;
    uint32_t remainder = 0;
    for (int bit = 31; bit >= 0; bit--) {
        remainder = (remainder << 1) | ((numerator >> bit) & 1u);
        quotient <<= 1;
        if (remainder >= denominator) {
            remainder -= denominator;
            quotient |= 1u;
        }
    }
    for (int bit = 0; bit < f_frac_bits; bit++) {
        remainder <<= 1;
        quotient <<= 1;
        if (remainder >= denominator) {
            remainder -= denominator;
            quotient |= 1u;
        }
    }
    return with_sign(quotient, (a < 0) != (b < 0));
}

fpm_t fpm_sqrt(fpm_t a) {
    if (a < 0) {
        return 0;
    }
    const uint32_t input = (uint32_t)a;
    uint32_t root = 0;
    uint32_t remainder = 0;

    for (int pair = 23; pair >= 0; pair--) {
        const uint32_t digit = pair >= 8
            ? (input >> (2 * (pair - 8))) & 3u : 0u;
        remainder = (remainder << 2) | digit;
        root <<= 1;
        const uint32_t trial = (root << 1) | 1u;
        if (remainder >= trial) {
            remainder -= trial;
            ++root;
        }
    }
    return (fpm_t)(root);
}

fpm_t fpm_tan(fpm_t angle) {
    static const fpm_t angles[] = {51472, 30386, 16055, 8150, 4091, 2047, 1024, 512, 256, 128, 64, 32, 16, 8, 4, 2, 1};
    const fpm_t half_pi = 102944;
    angle %= f_pi;
    if (angle > half_pi) angle -= f_pi;
    if (angle < -half_pi) angle += f_pi;
    if (angle == 0) return 0;

    fpm_t cosine = 39797;
    fpm_t sine = 0;
    for (int i = 0; i < 17; ++i) {
        const fpm_t dx = cosine / (1 << i);
        const fpm_t dy = sine / (1 << i);
        if (angle >= 0) {
            cosine -= dy;
            sine += dx;
            angle -= angles[i];
        } else {
            cosine += dy;
            sine -= dx;
            angle += angles[i];
        }
    }
    if (cosine == 0 || magnitude(sine) / magnitude(cosine) >= 32768u)
        return (sine < 0) != (cosine < 0) ? -INT32_MAX : INT32_MAX;
    return fpm_div(sine, cosine);
}

fpm_t fpm_rcp(fpm_t x){
    return with_sign(q16_rcp((uint32_t)x), false);
}


fpm_t fpm_rsqrt(fpm_t x){
    if (x <= 0) return 0;
    return fpm_rcp(fpm_sqrt(x));
}
