#ifndef RTWEEKEND_H
#define RTWEEKEND_H

#include "fpm.h"
#include <algorithm>
#include <memory>
#include <random>

using std::shared_ptr;
using std::make_shared;

constexpr fpm_t infinity = INT32_MAX;
constexpr fpm_t pi = f_pi;

inline std::mt19937& random_generator() {
    static std::mt19937 generator;
    return generator;
}

inline fpm_t random_fixed() {
    return static_cast<fpm_t>(static_cast<uint32_t>(random_generator()()) >> 16);
}

inline fpm_t random_fixed(fpm_t min, fpm_t max) {
    return min + fpm_mul(max - min, random_fixed());
}

inline int random_int(int min, int max) {
    return std::uniform_int_distribution<int>(min, max)(random_generator());
}

inline fpm_t clamp(fpm_t x, fpm_t min, fpm_t max) {
    return std::max(min, std::min(x, max));
}

inline fpm_t degrees_to_radians(fpm_t degrees) {
    return fpm_mul(degrees, pi) / 180;
}

#endif
