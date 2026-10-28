#ifndef CORE_WEEKEND_SCENE_H
#define CORE_WEEKEND_SCENE_H

#include "material.h"
#include "scene.h"

enum { weekend_capacity = 488 };

typedef struct {
    uint32_t state;
    uint32_t draws;
} weekend_rng;

typedef struct {
    sphere spheres[weekend_capacity];
    path_material materials[weekend_capacity];
    int32_t count;
    weekend_rng random;
} weekend_scene;

static inline weekend_rng weekend_rng_make(uint32_t seed){
    weekend_rng result = {seed == 0 ? UINT32_C(0xA341316C) : seed, 0};
    return result;
}

static inline fpm_t weekend_fraction(weekend_rng* random){
    uint32_t value = random->state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    random->state = value;
    ++random->draws;
    return (fpm_t)(value >> 16);
}

static inline vec3 weekend_random_color(weekend_rng* random, fpm_t minimum){
    const fpm_t red = fpm_add(minimum, fpm_mul(f_scale - minimum, weekend_fraction(random)));
    const fpm_t green = fpm_add(minimum, fpm_mul(f_scale - minimum, weekend_fraction(random)));
    const fpm_t blue = fpm_add(minimum, fpm_mul(f_scale - minimum, weekend_fraction(random)));
    return vec3_make(red, green, blue);
}

static inline void weekend_add(weekend_scene* scene, vec3 center, fpm_t radius,
    int32_t kind, vec3 albedo, fpm_t fuzz, fpm_t ior){
    if (scene->count >= weekend_capacity) return;
    const int32_t index = scene->count++;
    scene->spheres[index] = sphere_make(
        vec3_make(center.e[0] / 8, center.e[1] / 8, center.e[2] / 8), radius / 8, index);
    scene->materials[index] = path_material_make((material_kind)kind, albedo, fuzz, ior);
}

static inline void weekend_scene_make(weekend_scene* scene, uint32_t seed){
    scene->count = 0;
    scene->random = weekend_rng_make(seed);
    weekend_add(scene, vec3_make(0, -1000 * f_scale, 0), 1000 * f_scale,
        0, vec3_make(f_scale / 2, f_scale / 2, f_scale / 2), 0, 0);
    for (int32_t a = -11; a < 11; ++a){
        for (int32_t b = -11; b < 11; ++b){
            const fpm_t choose = weekend_fraction(&scene->random);
            const fpm_t x = fpm_add(a * f_scale,
                fpm_mul(9 * f_scale / 10, weekend_fraction(&scene->random)));
            const fpm_t z = fpm_add(b * f_scale,
                fpm_mul(9 * f_scale / 10, weekend_fraction(&scene->random)));
            const vec3 center = vec3_make(x, f_scale / 5, z);
            const vec3 separation = vec3_sub(center, vec3_make(4 * f_scale, f_scale / 5, 0));
            if (vec3_length(separation) <= 9 * f_scale / 10) continue;
            if (choose < 4 * f_scale / 5){
                const vec3 first = weekend_random_color(&scene->random, 0);
                const vec3 second = weekend_random_color(&scene->random, 0);
                weekend_add(scene, center, f_scale / 5, 0, vec3_mul(first, second), 0, 0);
            } else if (choose < 19 * f_scale / 20){
                const vec3 albedo = weekend_random_color(&scene->random, f_scale / 2);
                const fpm_t fuzz = fpm_mul(f_scale / 2, weekend_fraction(&scene->random));
                weekend_add(scene, center, f_scale / 5, 1, albedo, fuzz, 0);
            } else {
                weekend_add(scene, center, f_scale / 5, 2,
                    vec3_make(f_scale, f_scale, f_scale), 0, 3 * f_scale / 2);
            }
        }
    }
    weekend_add(scene, vec3_make(0, f_scale, 0), f_scale, 2,
        vec3_make(f_scale, f_scale, f_scale), 0, 3 * f_scale / 2);
    weekend_add(scene, vec3_make(-4 * f_scale, f_scale, 0), f_scale, 0,
        vec3_make(2 * f_scale / 5, f_scale / 5, f_scale / 10), 0, 0);
    weekend_add(scene, vec3_make(4 * f_scale, f_scale, 0), f_scale, 1,
        vec3_make(7 * f_scale / 10, 3 * f_scale / 5, f_scale / 2), 0, 0);
}

#endif
