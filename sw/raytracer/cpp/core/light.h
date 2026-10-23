#ifndef CORE_LIGHT_H
#define CORE_LIGHT_H

#include "vec3.h"
static inline fpm_t lambertian_cosine(vec3 normal, vec3 to_light){
    const fpm_t cosine = vec3_dot(normal, to_light);
    return cosine<0 ? 0 : cosine;
}

static inline vec3 lambertian_shade(vec3 albedo, fpm_t cosine, fpm_t ambient, fpm_t diffuse){
    const fpm_t direct =fpm_mul(diffuse, cosine);
    const fpm_t brightness = fpm_add(ambient, direct);
    return vec3_scale(albedo, brightness);
}

#endif