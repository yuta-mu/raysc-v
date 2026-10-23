#ifndef CORE_SCENE_H
#define CORE_SCENE_H

#include "sphere.h"

static inline bool scene_hit(const sphere* spheres, int32_t sphere_count,
        ray r, fpm_t t_min, fpm_t t_max, hit_record* rec){
    hit_record temp_rec;
    bool hit_anything = 0;
    fpm_t closest_so_far = t_max;
    for (int32_t i = 0; i < sphere_count; i++){
        if (sphere_hit(spheres[i], r, t_min, closest_so_far, &temp_rec)){
            hit_anything = true;
            closest_so_far = temp_rec.t;
            *rec = temp_rec;
        }
    }
    return hit_anything;
}

static inline bool scene_occluded(const sphere* spheres, int32_t sphere_count,
        ray r, fpm_t t_min, fpm_t t_max){
    hit_record temp_rec;
    for (int32_t i=0; i<sphere_count; ++i){
        if (sphere_hit(spheres[i], r, t_min, t_max, &temp_rec)) return true;
    }
    return false;
}
#endif
