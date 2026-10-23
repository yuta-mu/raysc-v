#ifndef CORE_RAY_H
#define CORE_RAY_H
#include "vec3.h"
typedef struct {
    vec3 orig;
    vec3 dir;
} ray;

static inline ray ray_make(vec3 origin, vec3 direction){
    ray result = {origin, direction};
    return result;
}

static inline vec3 ray_at(ray r, fpm_t t){
    return vec3_add(r.orig, vec3_scale(r.dir, t));
}

#endif