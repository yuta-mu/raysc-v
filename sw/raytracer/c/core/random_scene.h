#ifndef CORE_RANDOM_SCENE_H
#define CORE_RANDOM_SCENE_H

#include "camera.h"
#include "material.h"
#include "sphere.h"

enum { random_sphere_capacity = 65 };

static inline uint32_t random_scene_next(uint32_t* state){
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

static inline fpm_t random_scene_range(uint32_t* state, fpm_t minimum, fpm_t maximum){
    const fpm_t fraction = (fpm_t)(random_scene_next(state) >> 16);
    return fpm_add(minimum, fpm_mul(fpm_sub(maximum, minimum), fraction));
}

static inline int32_t random_scene_make(sphere* spheres, material* materials, uint32_t seed){
    uint32_t state = seed == 0 ? UINT32_C(0xA341316C) : seed;
    int32_t count = 1;
    spheres[0] = sphere_make(vec3_make(0, -100 * f_scale, 0), 100 * f_scale, 0);
    materials[0].albedo = vec3_make(f_scale / 2, f_scale / 2, f_scale / 2);
    materials[0].is_mirror = false;
    for (int attempt = 0; attempt < 20000 && count < random_sphere_capacity; ++attempt){
        const fpm_t radius = random_scene_range(&state, f_scale / 5, 11 * f_scale / 20);
        const fpm_t x = random_scene_range(&state, -5 * f_scale, 5 * f_scale);
        const fpm_t z = random_scene_range(&state, -7 * f_scale, 3 * f_scale);
        const vec3 center = vec3_make(x, radius, z);
        bool overlaps = false;
        for (int32_t i = 1; i < count; ++i){
            const vec3 separation = vec3_sub(center, spheres[i].center);
            const fpm_t distance = fpm_add(fpm_add(radius, spheres[i].radius), f_scale / 20);
            if (vec3_length_squared(separation) < fpm_mul(distance, distance)){
                overlaps = true;
                break;
            }
        }
        if (overlaps) continue;
        const bool mirror = (random_scene_next(&state) & 3u) == 0;
        const fpm_t minimum = mirror ? 7 * f_scale / 10 : 3 * f_scale / 20;
        const fpm_t maximum = mirror ? 49 * f_scale / 50 : 19 * f_scale / 20;
        const fpm_t red = random_scene_range(&state, minimum, maximum);
        const fpm_t green = random_scene_range(&state, minimum, maximum);
        const fpm_t blue = random_scene_range(&state, minimum, maximum);
        spheres[count] = sphere_make(center, radius, count);
        materials[count].albedo = vec3_make(red, green, blue);
        materials[count].is_mirror = mirror;
        ++count;
    }
    return count;
}

static inline camera random_scene_camera(int32_t width, int32_t height){
    const vec3 origin = vec3_make(9 * f_scale, 5 * f_scale, 10 * f_scale);
    const vec3 target = vec3_make(0, f_scale / 2, -2 * f_scale);
    const vec3 backward = vec3_unit_vector(vec3_sub(origin, target));
    const vec3 right = vec3_unit_vector(vec3_cross(vec3_make(0, f_scale, 0), backward));
    const vec3 up = vec3_unit_vector(vec3_cross(backward, right));
    const fpm_t aspect = fpm_from_ratio(width, height);
    const fpm_t half_height = 2 * f_scale / 5;
    camera cam;
    cam.origin = origin;
    cam.horizontal = vec3_scale(right, fpm_mul(2 * half_height, aspect));
    cam.vertical = vec3_scale(up, 2 * half_height);
    cam.lower_left_corner = vec3_sub(vec3_sub(vec3_sub(origin,
        vec3_scale(cam.horizontal, f_scale / 2)),
        vec3_scale(cam.vertical, f_scale / 2)), backward);
    return cam;
}

#endif
