#ifndef CORE_WEEKEND_H
#define CORE_WEEKEND_H

#include "bvh.h"
#include "path_camera.h"
#include "weekend_scene.h"

typedef struct {
    int32_t width;
    int32_t height;
    int32_t samples;
    int32_t depth;
    uint32_t seed;
    fpm_t defocus_angle;
} weekend_settings;

static inline bool weekend_camera_make(path_camera* cam, weekend_settings settings){
    return path_camera_make(cam, vec3_make(13 * f_scale / 8, 2 * f_scale / 8, 3 * f_scale / 8),
        vec3_make(0, 0, 0), vec3_make(0, f_scale, 0), 20 * f_scale,
        10 * f_scale / 8, settings.defocus_angle, settings.width, settings.height);
}

static inline vec3 weekend_sky(vec3 direction){
    direction = path_unit_vector(direction);
    if (vec3_length_squared(direction) == 0) return vec3_make(0, 0, 0);
    fpm_t t = fpm_add(direction.e[1], f_scale) / 2;
    if (t < 0) t = 0;
    if (t > f_scale) t = f_scale;
    const vec3 white = vec3_make(f_scale, f_scale, f_scale);
    const vec3 blue = vec3_make(f_scale / 2, 7 * f_scale / 10, f_scale);
    return vec3_add(vec3_scale(white, fpm_sub(f_scale, t)), vec3_scale(blue, t));
}

static inline vec3 weekend_ray_color(ray r, const sphere* spheres, int32_t count,
    const path_material* materials, const bvh* tree, int32_t depth, uint32_t* state){
    vec3 weight = vec3_make(f_scale, f_scale, f_scale);
    r.dir = path_unit_vector(r.dir);
    if (vec3_length_squared(r.dir) == 0) return vec3_make(0, 0, 0);
    for (int32_t bounce = 0; bounce < depth; ++bounce){
        hit_record rec = {vec3_make(0, 0, 0), vec3_make(0, 0, 0), 0, 0, false};
        const bool hit = tree ? bvh_hit(tree, spheres, r, 8, INT32_MAX, &rec)
            : path_scene_hit(spheres, count, r, 8, INT32_MAX, &rec);
        if (!hit) return vec3_mul(weight, weekend_sky(r.dir));
        rec.normal = path_unit_vector(rec.normal);
        const path_material mat = materials[rec.material_id];
        path_scatter_result scatter = path_material_scatter(mat, r.dir, rec.normal, rec.front_face, state);
        if (!scatter.scattered) return vec3_make(0, 0, 0);
        if (mat.kind == material_lambertian && vec3_dot(scatter.direction, rec.normal) < 0)
            scatter.direction = rec.normal;
        const vec3 direction = path_unit_vector(scatter.direction);
        if (vec3_length_squared(direction) == 0) return vec3_make(0, 0, 0);
        weight = vec3_mul(weight, scatter.attenuation);
        const fpm_t bias = mat.kind == material_dielectric && vec3_dot(direction, rec.normal) < 0 ? -8 : 8;
        r = ray_make(vec3_add(rec.p, vec3_scale(rec.normal, bias)), direction);
    }
    return vec3_make(0, 0, 0);
}

static inline vec3 weekend_pixel(const weekend_scene* scene, const bvh* tree, path_camera cam,
    weekend_settings settings, int32_t x, int32_t y, uint32_t* sampling, uint32_t* checksum){
    vec3 sum = vec3_make(0, 0, 0);
    for (int32_t sample = 0; sample < settings.samples; ++sample){
        const fpm_t s = (x * f_scale + random_fraction(sampling)) / settings.width;
        const fpm_t t = (y * f_scale + random_fraction(sampling)) / settings.height;
        uint32_t state = random_next(sampling);
        uint32_t lens = random_stream(state ^ UINT32_C(0x9e3779b9));
        const ray r = path_camera_get_ray(cam, s, t, &lens);
        sum = vec3_add(sum, weekend_ray_color(r, scene->spheres, scene->count,
            scene->materials, tree, settings.depth, &state));
        *checksum = *checksum * UINT32_C(16777619) + state;
    }
    return vec3_make(sum.e[0] / settings.samples, sum.e[1] / settings.samples, sum.e[2] / settings.samples);
}

static inline bool weekend_settings_valid(weekend_settings settings){
    return settings.width >= 1 && settings.width <= 32768
        && settings.height >= 1 && settings.height <= 32768
        && settings.samples >= 1 && settings.samples <= 4096
        && settings.depth >= 1 && settings.depth <= 100
        && settings.defocus_angle >= 0 && settings.defocus_angle <= 30 * f_scale;
}

#endif
