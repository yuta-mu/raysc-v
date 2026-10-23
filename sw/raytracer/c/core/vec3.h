#ifndef CORE_VEC3_H
#define CORE_VEC3_H

#include "../fpm.h"

typedef struct {
    fpm_t e[3];
} vec3;
static inline vec3 vec3_make(fpm_t x, fpm_t y, fpm_t z){
    vec3 result = {{x, y, z}};
    return result;
}

static inline vec3 vec3_add(vec3 u, vec3 v){
    fpm_t x,y,z;
    x = fpm_add(u.e[0], v.e[0]);
    y = fpm_add(u.e[1], v.e[1]);
    z = fpm_add(u.e[2], v.e[2]);
    return vec3_make(x, y, z);
}

static inline vec3 vec3_sub(vec3 u, vec3 v){
    fpm_t x,y,z;
    x = fpm_sub(u.e[0], v.e[0]);
    y = fpm_sub(u.e[1], v.e[1]);
    z = fpm_sub(u.e[2], v.e[2]);
    return vec3_make(x, y, z);
}

static inline vec3 vec3_neg(vec3 v){
    fpm_t x,y,z;
    x = fpm_sub(0, v.e[0]);
    y = fpm_sub(0, v.e[1]);
    z = fpm_sub(0, v.e[2]);
    return vec3_make(x, y, z);
}

static inline vec3 vec3_scale(vec3 v, fpm_t t){
    fpm_t x,y,z;
    x = fpm_mul(t, v.e[0]);
    y = fpm_mul(t, v.e[1]);
    z = fpm_mul(t, v.e[2]);
    return vec3_make(x, y, z);
}

static inline vec3 vec3_mul(vec3 u, vec3 v){
    fpm_t x,y,z;
    x = fpm_mul(u.e[0], v.e[0]);
    y = fpm_mul(u.e[1], v.e[1]);
    z = fpm_mul(u.e[2], v.e[2]);
    return vec3_make(x, y, z);
}

static inline fpm_t vec3_dot(vec3 u, vec3 v){
    const uint32_t p0 = (uint32_t)fpm_mul(u.e[0], v.e[0]);
    const uint32_t p1 = (uint32_t)fpm_mul(u.e[1], v.e[1]);
    const uint32_t p2 = (uint32_t)fpm_mul(u.e[2], v.e[2]);
    const uint32_t sum = p0 + p1 + p2;
    if (sum <= INT32_MAX) {
        return (fpm_t)sum;
    }
    else {
        return -1 - (fpm_t)(UINT32_MAX - sum);
  }
}

static inline fpm_t vec3_length_squared(vec3 v) {
  return vec3_dot(v, v);
}

static inline vec3 vec3_cross(vec3 u, vec3 v){
    fpm_t x,y,z;
    x = fpm_sub(fpm_mul(u.e[1], v.e[2]), fpm_mul(u.e[2], v.e[1]));
    y = fpm_sub(fpm_mul(u.e[2], v.e[0]), fpm_mul(u.e[0], v.e[2]));
    z = fpm_sub(fpm_mul(u.e[0], v.e[1]), fpm_mul(u.e[1], v.e[0]));
    return vec3_make(x, y, z);
}

static inline vec3 vec3_unit_vector(vec3 v){
    const fpm_t limit = 104 * f_scale;
    while (v.e[0] > limit || v.e[0] < -limit
            || v.e[1] > limit || v.e[1] < -limit
            || v.e[2] > limit || v.e[2] < -limit) {
            v = vec3_scale(v, f_scale / 2);
        }
    const fpm_t inverse_length = fpm_rsqrt(vec3_length_squared(v));
    return vec3_scale(v,inverse_length);
}

static inline vec3 vec3_reflect(vec3 v, vec3 n){
    const fpm_t d = vec3_dot(v, n);
    const vec3 result = vec3_sub(v, vec3_scale(n, fpm_add(d, d)));
    return result;
}

static inline fpm_t vec3_length(vec3 v){
    vec3 scaled = v;
    int halvings = 0;
    const fpm_t limit = 104 * f_scale;
    while (scaled.e[0] > limit || scaled.e[0] < -limit
        || scaled.e[1] > limit || scaled.e[1] < -limit
        || scaled.e[2] > limit || scaled.e[2] < -limit) {
        scaled = vec3_scale(scaled, f_scale / 2);
        ++halvings;
    }
    fpm_t result = fpm_sqrt(vec3_length_squared(scaled));
    while (halvings > 0){
      result = fpm_add(result, result);
      --halvings;
    }
    return result;
}

#endif