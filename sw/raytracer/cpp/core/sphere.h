#ifndef CORE_SPHERE_H
#define CORE_SPHERE_H

#include "hittable.h"
#include "vec3.h"

typedef struct {
    vec3 center;
    fpm_t radius;
    int32_t material_id;
} sphere;

static inline sphere sphere_make(
    vec3 center, fpm_t radius, int32_t material_id){
    sphere result = {center, radius, material_id};
    return result;
}

static inline uint32_t sphere_magnitude(fpm_t value){
    const uint32_t bits = (uint32_t)value;
    return value < 0 ? 0u - bits : bits;
}

static inline uint32_t sphere_component_scale(vec3 value){
    uint32_t scale = sphere_magnitude(value.e[0]);
    const uint32_t my = sphere_magnitude(value.e[1]);
    const uint32_t mz = sphere_magnitude(value.e[2]);
    if(scale < my)scale = my;
    if(scale < mz)scale = mz;
    return scale;
}

static inline fpm_t sphere_scaled_length(vec3 value){
    const uint32_t scale = sphere_component_scale(value);
    if (scale == 0) return 0;
    if (scale >= f_scale) return vec3_length(value);
    const fpm_t s = (fpm_t)scale;
    const fpm_t inverse = fpm_rcp(s);
    const vec3 value_i = vec3_scale(value, inverse);
    return fpm_mul(s, vec3_length(value_i));    
}

static inline fpm_t sphere_distance_ratio(
    fpm_t value, uint32_t positive_divisor){
    if (sphere_magnitude(value) / positive_divisor >= 32768u){
        return value < 0 ? -INT32_MAX : INT32_MAX;
    }
    if (positive_divisor > INT32_MAX) return value / 32768;
    else{
        return fpm_div(value, (fpm_t)positive_divisor);
    }
}

static inline bool sphere_hit(
    sphere s, ray r, fpm_t t_min, fpm_t t_max, hit_record* rec){
    uint32_t scale = sphere_component_scale(r.dir);     
    uint32_t extent_bits =sphere_magnitude(s.radius);
    if (scale == 0 || extent_bits == 0 || extent_bits > INT32_MAX) return false;
    const fpm_t extent = (fpm_t)extent_bits;
    const fpm_t inverse_scale =
    scale > INT32_MAX ? 2 : fpm_rcp((fpm_t)scale);

    const vec3 direction = vec3_scale(r.dir, inverse_scale);
    const fpm_t a = vec3_length_squared(direction);
    const vec3 offset = vec3_sub(r.orig, s.center);
    const fpm_t projection =
        fpm_div(vec3_dot(offset, direction), a);
    const vec3 perpendicular =
        vec3_sub(offset, vec3_scale(direction, projection));
    const fpm_t distance = sphere_scaled_length(perpendicular);
    if (distance < 0 || distance >= extent) return false;
    const fpm_t gap = fpm_sub(extent, distance);
    const fpm_t sum = fpm_add(extent, distance);
    fpm_t chord;
    if (sum > 0 &&(sum <= f_scale || gap <= fpm_div(INT32_MAX, sum))){
        chord = fpm_sqrt(fpm_mul(gap, sum));
    }
    else{
        const fpm_t ratio = fpm_div(distance, extent);
        const fpm_t inner = fpm_sub(f_scale, fpm_mul(ratio, ratio)); 
        chord = fpm_mul(extent, fpm_sqrt(inner < 0 ? 0 : inner));
    }
    chord = fpm_div(chord, fpm_sqrt(a));
    const fpm_t neg_projection = fpm_sub(0, projection);
    fpm_t t = sphere_distance_ratio(fpm_sub(neg_projection, chord), scale);
    if (t <= t_min || t >= t_max){
        t = sphere_distance_ratio(fpm_add(neg_projection, chord), scale);
    }
    if (t <= t_min || t >= t_max)return false;
    rec->t = t;
    rec->p = ray_at(r, t);
    const vec3 outward_normal = vec3_scale(vec3_sub(rec->p, s.center), fpm_rcp(s.radius));\
    hit_record_set_face_normal(rec, r, outward_normal);
    rec->material_id = s.material_id;
    return true;

}


#endif