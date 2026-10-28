#ifndef CORE_MATERIAL_H
#define CORE_MATERIAL_H

#include "vec3.h"
#include <stdbool.h>
#include "random.h"

typedef struct {
    vec3 albedo;
    bool is_mirror;
} material;

typedef enum {
    material_lambertian = 0,
    material_metal = 1,
    material_dielectric = 2
} material_kind;

typedef struct {
    material_kind kind;
    vec3 albedo;
    fpm_t fuzz;
    fpm_t ior;
} path_material;

typedef struct {
    vec3 direction;
    vec3 attenuation;
    bool scattered;
} path_scatter_result;

static inline path_material path_material_make(material_kind kind, vec3 albedo, fpm_t fuzz, fpm_t ior){
    path_material result;
    result.kind = kind;
    result.albedo = albedo;
    result.fuzz = fuzz;
    if (result.fuzz < 0) result.fuzz = 0;
    if (result.fuzz > f_scale) result.fuzz = f_scale;
    result.ior = ior;
    return result;
}

static inline vec3 path_unit_vector(vec3 direction){
    uint32_t max_abs = 0;
    for (int i = 0; i<3; ++i){
        uint32_t const bits = (uint32_t)direction.e[i];
        uint32_t const magnitude = direction.e[i] < 0 ? 0u - bits : bits;
        if (magnitude > max_abs){
            max_abs = magnitude;
        }
    }
    if (max_abs==0)return direction;
    while (max_abs < f_scale / 2){
        direction = vec3_add(direction, direction);
        max_abs += max_abs;
    }
    return vec3_unit_vector(direction);
}

static inline vec3 path_lambertian_direction(vec3 normal, uint32_t* state){
    vec3 direction = vec3_add(normal, random_unit_vector(state));
    if (vec3_length_squared(direction) == 0){
        direction = normal;
    }
    return direction;
}

static inline fpm_t path_refraction_ratio(fpm_t ior, bool front_face){
    if (front_face) return fpm_div(f_scale, ior);
    return ior;
}

static inline fpm_t path_cos_theta(vec3 unit_direction, vec3 normal){
    fpm_t cosine = vec3_dot(vec3_neg(unit_direction), normal);
    cosine = cosine < 0 ? 0 : cosine > f_scale ? f_scale : cosine;
    return cosine;
}

static inline fpm_t path_sin_theta(fpm_t cosine){
    fpm_t const sin_squared = fpm_sub(f_scale, fpm_mul(cosine, cosine));
    return fpm_sqrt(sin_squared);
}

static inline bool path_cannot_refract(fpm_t refraction_ratio, fpm_t sine){
    fpm_t const product = fpm_mul(refraction_ratio, sine);
    if( product > f_scale)return true;
    if (product < f_scale)return false;
    uint32_t const fraction = ((uint32_t)refraction_ratio * (uint32_t)sine) & (f_scale - 1u);
    return fraction != 0;

}

static inline vec3 path_refract(vec3 unit_direction, vec3 normal, fpm_t refraction_ratio, fpm_t cosine){
    vec3 const perpendicular = vec3_scale(vec3_add(unit_direction, vec3_scale(normal, cosine)), refraction_ratio);
    if (refraction_ratio == f_scale) return unit_direction;
    fpm_t k = fpm_sub(f_scale, vec3_length_squared(perpendicular));
    if (k < 0) k = 0;
    vec3 const parallel = vec3_scale(normal, fpm_sub(0, fpm_sqrt(k)));
    return vec3_add(perpendicular, parallel);
}

static inline fpm_t path_reflectance(fpm_t cosine, fpm_t refraction_ratio){
    fpm_t const base = fpm_div(fpm_sub(f_scale, refraction_ratio), fpm_add(f_scale, refraction_ratio));
    fpm_t const r0 = fpm_mul(base, base);
    fpm_t const x = fpm_sub(f_scale, cosine);
    fpm_t const x2 = fpm_mul(x, x);
    fpm_t const x4 = fpm_mul(x2, x2);
    fpm_t const x5 = fpm_mul(x4, x);
    return fpm_add(r0, fpm_mul(fpm_sub(f_scale, r0), x5));
}

static inline path_scatter_result path_dielectric_scatter(fpm_t ior, vec3 incoming, vec3 normal, bool front_face, uint32_t* state){
    path_scatter_result result;
    vec3 const unit_direction = path_unit_vector(incoming);
    fpm_t const ratio = path_refraction_ratio(ior, front_face);
    fpm_t const cosine = path_cos_theta(unit_direction, normal);
    fpm_t const sine = path_sin_theta(cosine);
    if (path_cannot_refract(ratio, sine) || path_reflectance(cosine, ratio) > random_fraction(state)){
        result.direction = vec3_reflect(unit_direction, normal);
    }
    else result.direction = path_refract(unit_direction, normal, ratio, cosine);
    result.attenuation = vec3_make(f_scale, f_scale, f_scale);
    result.scattered = true;
    return result;
}

static inline path_scatter_result path_lambertian_scatter(vec3 albedo, vec3 normal, uint32_t* state){
    path_scatter_result result;
    result.direction = path_lambertian_direction(normal, state);
    result.attenuation = albedo;
    result.scattered = true;
    return result;
}

static inline path_scatter_result path_metal_scatter(vec3 albedo, vec3 incoming, vec3 normal, fpm_t fuzz, uint32_t* state){
    path_scatter_result result;
    result.direction = vec3_reflect(incoming, normal);
    if (fuzz > 0){
        vec3 const reflected = path_unit_vector(result.direction);
        vec3 const offset = vec3_scale(random_unit_vector(state), fuzz);
        result.direction = vec3_add(reflected, offset);
    }
    result.attenuation = albedo;
    result.scattered = vec3_dot(result.direction, normal) > 0;
    return result;
}

static inline path_scatter_result path_material_scatter(path_material mat, vec3 incoming, vec3 normal, bool front_face, uint32_t* state){
    if (mat.kind == material_lambertian) return path_lambertian_scatter(mat.albedo, normal, state);
    if (mat.kind == material_metal) return path_metal_scatter(mat.albedo, incoming, normal, mat.fuzz, state);
    if (mat.kind == material_dielectric)return path_dielectric_scatter(mat.ior, incoming, normal, front_face, state);
    path_scatter_result result;
    result.direction = vec3_make(0, 0, 0);
    result.attenuation = vec3_make(0, 0, 0);
    result.scattered = false;
    return result;
}


#endif