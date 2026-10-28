#ifndef CORE_RANDOM_H
#define CORE_RANDOM_H

#include <stdint.h>
#include "../fpm.h"
#include "vec3.h"

static inline uint32_t random_next(uint32_t* state){
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

static inline fpm_t random_fraction(uint32_t* state){
    fpm_t const raw = (fpm_t)(random_next(state) >> 16);
    return raw;
}

static inline fpm_t random_range(uint32_t* state, fpm_t minimum, fpm_t maximum){
    fpm_t const fraction = random_fraction(state);
    fpm_t const range = fpm_sub(maximum, minimum);
    return fpm_add(minimum, fpm_mul(range, fraction));
}

static inline vec3 random_vec3_range(uint32_t* state, fpm_t minimum, fpm_t maximum){
    fpm_t const x = random_range(state, minimum, maximum);
    fpm_t const y = random_range(state, minimum, maximum);
    fpm_t const z = random_range(state, minimum, maximum);
    return vec3_make(x,y,z);
}

static inline vec3 random_in_unit_sphere(uint32_t* state){
    while(1){
        vec3 const p = random_vec3_range(state, -f_scale, f_scale);
        fpm_t const length_squared = vec3_length_squared(p);
        if (length_squared < f_scale)return p;
    }
}

static inline uint32_t random_seed(uint32_t seed){
    return seed == 0 ? UINT32_C(0xA341316C) : seed;
}

static inline uint32_t random_stream(uint32_t seed){
    seed ^= seed >> 16;
    seed *= UINT32_C(0x7feb352d);
    seed ^= seed >> 15;
    seed *= UINT32_C(0x846ca68b);
    seed ^= seed >> 16;
    return random_seed(seed);
}

static inline vec3 random_in_unit_disk(uint32_t* state){
    while (1){
        const fpm_t x = random_range(state, -f_scale, f_scale);
        const fpm_t y = random_range(state, -f_scale, f_scale);
        const uint32_t ax = x < 0 ? 0u - (uint32_t)x : (uint32_t)x;
        const uint32_t ay = y < 0 ? 0u - (uint32_t)y : (uint32_t)y;
        if (ax >= f_scale || ay >= f_scale) continue;
        const uint32_t xx = ax * ax;
        const uint32_t yy = ay * ay;
        if (UINT32_MAX - xx >= yy) return vec3_make(x, y, 0);
    }
}

static inline vec3 random_unit_vector(uint32_t* state){
    while (1){
        vec3 p = random_in_unit_sphere(state);
        fpm_t max_abs = 0;
        for (int axis = 0; axis < 3; ++axis){
            fpm_t const value = p.e[axis] < 0 ? -p.e[axis] : p.e[axis];
            if (value > max_abs){
                max_abs = value;
            }
        }
        if (max_abs == 0) continue;
        while(max_abs < f_scale / 2){
            p = vec3_add(p, p);
            max_abs = fpm_add(max_abs, max_abs);
        }
        return vec3_unit_vector(p);
    }
}


#endif
