#include "fpm.h"

namespace {
inline uint32_t magnitude(fpm_t value) {
    const uint32_t bits = static_cast<uint32_t>(value);
    return value < 0 ? 0u - bits : bits;
}
inline fpm_t with_sign(uint32_t value, bool negative) {
    if (!negative) {
        return static_cast<fpm_t>(value);
    }
    if (value == 0x80000000u) {
        return INT32_MIN;
    }
    return -static_cast<fpm_t>(value);
}

inline uint32_t multiply_16(uint32_t a, uint32_t b) {
    uint32_t product = 0;
    while (b != 0) {
        if ((b & 1u) != 0) {
            product += a;
        }
        a <<= 1;
        b >>= 1;
    }
    return product;
}

}

fpm_t fpm_mul(fpm_t a, fpm_t b) {

    if (a == 0 || b == 0) {
        return 0;
    }
    const uint32_t ua = magnitude(a);
    const uint32_t ub = magnitude(b);
    const uint32_t a_high = ua >> f_frac_bits;
    const uint32_t a_low = ua & 0xffffu;
    const uint32_t b_high = ub >> f_frac_bits;
    const uint32_t b_low = ub & 0xffffu;
    const uint32_t scaled = (multiply_16(a_high, b_high) << f_frac_bits)
                        + multiply_16(a_high, b_low)
                        + multiply_16(a_low, b_high)
                        + (multiply_16(a_low, b_low) >> f_frac_bits);
    return with_sign(scaled, (a < 0) != (b < 0));
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
    const uint32_t input = static_cast<uint32_t>(a);
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
    return static_cast<fpm_t>(root);
}

fpm_t fpm_tan(fpm_t angle) {
    static const fpm_t angles[] = {51472, 30386, 16055, 8150, 4091, 2047, 1024, 512, 256, 128, 64, 32, 16, 8, 4, 2, 1};
    constexpr fpm_t half_pi = 102944;
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

namespace {

const fpm_t angles[] = {51472, 30386, 16055, 8150, 4091, 2047, 1024, 512, 256, 128, 64, 32, 16, 8, 4, 2, 1};

void sin_cos(fpm_t angle, fpm_t& sine, fpm_t& cosine) {
    constexpr fpm_t half_pi = 102944;
    angle %= 2 * f_pi;
    if (angle > f_pi) angle -= 2 * f_pi;
    if (angle < -f_pi) angle += 2 * f_pi;
    bool negative_cosine = false;
    if (angle > half_pi) {
        angle = f_pi - angle;
        negative_cosine = true;
    } else if (angle < -half_pi) {
        angle = -f_pi - angle;
        negative_cosine = true;
    }

    sine = 0;
    cosine = f_scale;
    if (angle == half_pi || angle == -half_pi) {
        sine = angle < 0 ? -f_scale : f_scale;
        cosine = 0;
    } else if (angle != 0) {
        cosine = 39797;
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
        if (sine > f_scale) sine = f_scale;
        if (sine < -f_scale) sine = -f_scale;
        if (cosine > f_scale) cosine = f_scale;
        if (cosine < -f_scale) cosine = -f_scale;
    }
    if (negative_cosine) cosine = -cosine;
}

}

fpm_t fpm_sin(fpm_t angle) {
    fpm_t sine, cosine;
    sin_cos(angle, sine, cosine);
    return sine;
}

fpm_t fpm_cos(fpm_t angle) {
    fpm_t sine, cosine;
    sin_cos(angle, sine, cosine);
    return cosine;
}

fpm_t fpm_atan2(fpm_t y, fpm_t x) {
    constexpr fpm_t half_pi = 102944;
    if (x == 0) return y == 0 ? 0 : (y < 0 ? -half_pi : half_pi);
    if (y == 0) return x < 0 ? f_pi : 0;
    while (magnitude(x) > static_cast<uint32_t>(f_scale)
           || magnitude(y) > static_cast<uint32_t>(f_scale)) {
        x /= 2;
        y /= 2;
    }
    const fpm_t scale = static_cast<fpm_t>(magnitude(x) > magnitude(y) ? magnitude(x) : magnitude(y));
    x = fpm_div(x, scale);
    y = fpm_div(y, scale);
    fpm_t angle = 0;
    if (x < 0) {
        angle = y < 0 ? -f_pi : f_pi;
        x = -x;
        y = -y;
    }
    for (int i = 0; i < 17; ++i) {
        const fpm_t dx = x / (1 << i);
        const fpm_t dy = y / (1 << i);
        if (y > 0) {
            x += dy;
            y -= dx;
            angle += angles[i];
        } else if (y < 0) {
            x -= dy;
            y += dx;
            angle -= angles[i];
        } else {
            break;
        }
    }
    return angle;
}

fpm_t fpm_asin(fpm_t value) {
    if (value > f_scale) value = f_scale;
    if (value < -f_scale) value = -f_scale;
    return fpm_atan2(value, fpm_sqrt(f_scale - fpm_mul(value, value)));
}

fpm_t fpm_log(fpm_t value) {
    if (value <= 0) return -INT32_MAX;
    int exponent = 0;
    while (value < f_scale) {
        value *= 2;
        --exponent;
    }
    while (value >= 2 * f_scale) {
        value /= 2;
        ++exponent;
    }
    const fpm_t x = fpm_div(value - f_scale, value + f_scale);
    const fpm_t squared = fpm_mul(x, x);
    fpm_t term = x;
    fpm_t sum = x;
    for (int i = 3; i <= 19; i += 2) {
        term = fpm_mul(term, squared);
        sum += term / i;
    }
    return 2 * sum + exponent * 45426;
}

fpm_t fpm_div_clamped(fpm_t a, fpm_t b) {
    if (b == 0 || magnitude(a) / magnitude(b) >= 32768u)
        return (a < 0) != (b < 0) ? -INT32_MAX : INT32_MAX;
    return fpm_div(a, b);
}
