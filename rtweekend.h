#ifndef RTWEEKEND_H
#define RTWEEKEND_H

#include <cmath>
#include <cstdlib>
#include <limits>
#include <memory>
#include <cstdlib>
#include <random>

// using
using std::shared_ptr;
using std::make_shared;
using std::sqrt;

// 定数
const double infinity = std::numeric_limits<double>::infinity();
const double pi = 3.1415926535897932385;

inline double random_double() {
    static std::uniform_real_distribution<double> distribution(0.0, 1.0);
    static std::mt19937 generator;
    return distribution(generator);
}

inline double random_double(double min, double max) {
    // [min,max) の実数乱数を返す
    return min + (max-min)*random_double();
}

inline double clamp(double x, double min, double max) {
    if(x < min) return min;
    if(x > max) return max;
    return x;
}

// ユーティリティ関数
inline double degrees_to_radians(double degrees) {
    return degrees * pi / 180;
}

// 共通ヘッダー
#include "ray.h"
#include "vec3.h"

#endif