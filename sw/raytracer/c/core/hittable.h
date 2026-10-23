#ifndef CORE_HITTABLE_H
#define CORE_HITTABLE_H

#include "ray.h"
#include <stdbool.h>

typedef struct {
    vec3 p;
    vec3 normal;
    int32_t material_id;
    fpm_t t;
    bool front_face;
} hit_record;

static inline void hit_record_set_face_normal(
    hit_record* rec, ray r, vec3 outward_normal){
    rec->front_face = vec3_dot(r.dir, outward_normal) < 0;
    if (rec->front_face) rec->normal = outward_normal;
    else rec->normal = vec3_neg(outward_normal);
}

#endif