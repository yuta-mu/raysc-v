#include "fpm.h"

namespace {
// fpm_t の絶対値を返す。
inline uint32_t magnitude(fpm_t value) {
    const uint32_t bits = static_cast<uint32_t>(value);
    return value < 0 ? 0u - bits : bits;
}
// 絶対値を符号付き整数に戻す。
inline fpm_t with_sign(uint32_t value, bool negative) {
    if (!negative) {
        return static_cast<fpm_t>(value);
    }
    if (value == 0x80000000u) {// =2147483648
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

} // namespace

fpm_t fpm_mul(fpm_t a, fpm_t b) {
//上位16bitと下位16bitに分けて計算する。
//これにより32bit演算を４回組み合わせて64bitの結果を得ることができる。

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
    // 除数が2の累乗の場合
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
    //それ以外。イメージは筆算
    uint32_t quotient = 0;//整数部
    uint32_t remainder = 0;//その余り
    for (int bit = 31; bit >= 0; bit--) {//整数部の計算>分子を1bitずつ取り込む
        remainder = (remainder << 1) | ((numerator >> bit) & 1u);
        quotient <<= 1;
        if (remainder >= denominator) {
            remainder -= denominator;
            quotient |= 1u;
        }
    }
    for (int bit = 0; bit < f_frac_bits; bit++) {//小数点以下の計算
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
        root <<= 1; //余りの次の2bitを下ろすとrootは左に1bitシフト
        const uint32_t trial = (root << 1) | 1u;//(R+1)^2-R^2=2R+1
        if (remainder >= trial) {
            remainder -= trial;
            ++root;
        }
    }
    //二乗そのものを計算せず、候補を1増やすために必要な差だけを計算している
    return static_cast<fpm_t>(root);
}
