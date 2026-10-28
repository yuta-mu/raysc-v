#ifndef CORE_PATH_CAMERA_H
#define CORE_PATH_CAMERA_H

#include "camera.h"
#include "material.h"

typedef struct {
    camera view;
    vec3 disk_u;
    vec3 disk_v;
    bool defocus;
} path_camera;

static inline bool path_camera_make(path_camera* result, vec3 origin, vec3 target,
    vec3 up, fpm_t vfov, fpm_t focus, fpm_t defocus_angle, int32_t width, int32_t height){
    if (width < 1 || width > 32768 || height < 1 || height > 32768
        || vfov <= 0 || vfov >= 179 * f_scale || focus <= 0
        || focus > 16 * f_scale || defocus_angle < 0 || defocus_angle > 30 * f_scale) return false;
    const vec3 w = path_unit_vector(vec3_sub(origin, target));
    const vec3 u = path_unit_vector(vec3_cross(up, w));
    if (vec3_length_squared(w) == 0 || vec3_length_squared(u) == 0) return false;
    const vec3 v = vec3_cross(w, u);
    const fpm_t theta = fpm_mul(vfov, f_pi) / 180;
    const fpm_t viewport_height = 2 * fpm_tan(theta / 2);
    const fpm_t viewport_width = fpm_mul(fpm_from_ratio(width, height), viewport_height);
    result->view.origin = origin;
    result->view.horizontal = vec3_scale(u, fpm_mul(focus, viewport_width));
    result->view.vertical = vec3_scale(v, fpm_mul(focus, viewport_height));
    result->view.lower_left_corner = vec3_sub(vec3_sub(vec3_sub(origin,
        vec3_scale(result->view.horizontal, f_scale / 2)),
        vec3_scale(result->view.vertical, f_scale / 2)), vec3_scale(w, focus));
    const fpm_t radius = fpm_mul(focus, fpm_tan(fpm_mul(defocus_angle, f_pi) / 360));
    result->disk_u = vec3_scale(u, radius);
    result->disk_v = vec3_scale(v, radius);
    result->defocus = defocus_angle > 0 && radius > 0;
    return true;
}

static inline ray path_camera_get_ray(path_camera cam, fpm_t s, fpm_t t, uint32_t* state){
    const ray pinhole = camera_get_ray(cam.view, s, t);
    if (!cam.defocus) return pinhole;
    const vec3 disk = random_in_unit_disk(state);
    const vec3 offset = vec3_add(vec3_scale(cam.disk_u, disk.e[0]), vec3_scale(cam.disk_v, disk.e[1]));
    return ray_make(vec3_add(pinhole.orig, offset), vec3_sub(pinhole.dir, offset));
}

#endif
