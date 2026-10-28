#ifndef CORE_PATH_GEOMETRY_H
#define CORE_PATH_GEOMETRY_H

#include "scene.h"

static inline fpm_t path_scale_distance(fpm_t value, int shift){
    while (shift > 0){
        if (value > INT32_MAX / 2) return INT32_MAX;
        if (value < INT32_MIN / 2) return INT32_MIN;
        value += value;
        --shift;
    }
    while (shift < 0){
        value /= 2;
        ++shift;
    }
    return value;
}

static inline bool path_sphere_hit(sphere s, ray r, fpm_t t_min, fpm_t t_max, hit_record* rec){
    if (s.radius <= 0 || sphere_component_scale(r.dir) == 0) return false;
    vec3 offset = vec3_sub(r.orig, s.center);
    fpm_t radius = s.radius;
    int shift = 0;
    while (radius < f_scale && sphere_component_scale(offset) < 32u * f_scale){
        radius += radius;
        offset = vec3_add(offset, offset);
        ++shift;
    }
    while (radius > 64 * f_scale || sphere_component_scale(offset) > 64u * f_scale){
        radius /= 2;
        offset = vec3_scale(offset, f_scale / 2);
        --shift;
    }
    const fpm_t local_min = path_scale_distance(t_min, shift);
    const fpm_t local_max = path_scale_distance(t_max, shift);
    fpm_t t;
    if (s.radius < f_scale){
        hit_record local;
        if (!sphere_hit(sphere_make(vec3_make(0, 0, 0), radius, s.material_id),
            ray_make(offset, r.dir), local_min, local_max, &local)) return false;
        t = local.t;
    } else {
        const fpm_t a = vec3_length_squared(r.dir);
        if (a <= 0) return false;
        const fpm_t h = vec3_dot(offset, r.dir);
        const fpm_t c = fpm_sub(vec3_length_squared(offset), fpm_mul(radius, radius));
        const fpm_t discriminant = fpm_sub(fpm_mul(h, h), fpm_mul(a, c));
        if (discriminant <= 0) return false;
        const fpm_t root = fpm_sqrt(discriminant);
        const fpm_t q = fpm_sub(fpm_sub(0, h), h >= 0 ? root : fpm_sub(0, root));
        if (q == 0) return false;
        fpm_t first = fpm_div(q, a);
        fpm_t second = fpm_div(c, q);
        if (first > 0 && first < INT32_MAX) ++first;
        if (second > 0 && second < INT32_MAX) ++second;
        if (first > second){
            const fpm_t swap = first;
            first = second;
            second = swap;
        }
        t = first > local_min && first < local_max ? first : second;
        if (t <= local_min || t >= local_max) return false;
    }
    t = path_scale_distance(t, -shift);
    if (t <= t_min || t >= t_max) return false;
    rec->t = t;
    rec->p = ray_at(r, t);
    const vec3 normal = vec3_scale(vec3_sub(rec->p, s.center), fpm_rcp(s.radius));
    hit_record_set_face_normal(rec, r, normal);
    rec->material_id = s.material_id;
    return true;
}

static inline bool path_scene_hit(const sphere* spheres, int32_t count, ray r,
    fpm_t t_min, fpm_t t_max, hit_record* rec){
    bool found = false;
    fpm_t closest = t_max;
    for (int32_t i = 0; i < count; ++i){
        hit_record candidate;
        if (path_sphere_hit(spheres[i], r, t_min, closest, &candidate)){
            *rec = candidate;
            closest = candidate.t;
            found = true;
        }
    }
    return found;
}

#endif
