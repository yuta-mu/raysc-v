#ifndef CORE_CAMERA_H
#define CORE_CAMERA_H

#include "ray.h"

typedef struct {
    vec3 origin;
    vec3 lower_left_corner;
    vec3 horizontal;
    vec3 vertical;
} camera;

static inline ray camera_get_ray(camera cam, fpm_t s, fpm_t t){
    const vec3 hor_s = vec3_scale(cam.horizontal, s);
    const vec3 ver_t = vec3_scale(cam.vertical, t);
    const vec3 point = vec3_add(cam.lower_left_corner, vec3_add(hor_s, ver_t));
    const vec3 direction = vec3_sub(point, cam.origin);
    return ray_make(cam.origin, direction);
}



#endif