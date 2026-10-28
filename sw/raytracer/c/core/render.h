#ifndef CORE_RENDER_H
#define CORE_RENDER_H

#include "scene.h"
#include "light.h"
#include "material.h"

void render_image(void);

static inline ray shadow_ray_make(hit_record rec, vec3 to_light){
    const fpm_t bias = f_scale / 1000;
    const vec3 movement = vec3_scale(rec.normal, bias);
    const vec3 start = vec3_add(rec.p, movement);
    return ray_make(start, to_light);
}

static inline ray reflected_ray_make(ray r, hit_record rec){
    const vec3 direction = vec3_reflect(r.dir, rec.normal);
    const fpm_t bias = f_scale / 1000;
    const vec3 origin = vec3_add(rec.p, vec3_scale(rec.normal, bias));
    return ray_make(origin, direction);
}

static inline ray scattered_ray_make(hit_record rec, vec3 direction, bool can_transmit){
    fpm_t const bias = f_scale / 1000;
    fpm_t const offset = can_transmit && vec3_dot(direction, rec.normal) < 0 ? fpm_sub(0, bias) : bias;
    vec3 const origin = vec3_add(rec.p, vec3_scale(rec.normal, offset));
    return ray_make(origin, direction);
}

static inline vec3 ray_color(ray r, const sphere* spheres, int32_t sphere_count){
    hit_record rec;
    const vec3 white = vec3_make(f_scale, f_scale, f_scale);
    const vec3 blue = vec3_make(f_scale / 2, 7 * f_scale / 10, f_scale);
    if (scene_hit(spheres, sphere_count, r, f_scale / 1000, INT32_MAX, &rec)){
        return vec3_scale(vec3_add(rec.normal, white), f_scale / 2);
    }
    const vec3 unit_direction = vec3_unit_vector(r.dir);
    const fpm_t t = fpm_add(unit_direction.e[1], f_scale) / 2;
    return vec3_add(vec3_scale(white, fpm_sub(f_scale, t)), vec3_scale(blue, t));
}

static inline vec3 ray_color_lit(ray r, const sphere* spheres, int32_t sphere_count,
    const vec3* albedos, vec3 to_light, fpm_t ambient, fpm_t diffuse){
        hit_record rec;
        const vec3 white = vec3_make(f_scale, f_scale, f_scale);
        const vec3 blue = vec3_make(f_scale / 2, 7 * f_scale / 10, f_scale);
        if (scene_hit(spheres, sphere_count, r, f_scale / 1000, INT32_MAX, &rec)){
                    const vec3 albedo = albedos[rec.material_id];
                    const fpm_t cosine = lambertian_cosine(rec.normal, to_light); 
                    return lambertian_shade(albedo, cosine, ambient, diffuse);
        }
        const vec3 unit_direction = vec3_unit_vector(r.dir);
        const fpm_t t = fpm_add(unit_direction.e[1], f_scale) / 2;
        return vec3_add(vec3_scale(white, fpm_sub(f_scale, t)), vec3_scale(blue, t));
    }

static inline vec3 ray_color_shadowed(ray r, const sphere* spheres, int32_t sphere_count,
    const vec3* albedos, vec3 to_light, fpm_t ambient, fpm_t diffuse){
        hit_record rec;
        const vec3 white = vec3_make(f_scale, f_scale, f_scale);
        const vec3 blue = vec3_make(f_scale / 2, 7 * f_scale / 10, f_scale);
        if (scene_hit(spheres, sphere_count, r, f_scale / 1000, INT32_MAX, &rec)){
                    const vec3 albedo = albedos[rec.material_id];
                    fpm_t cosine = lambertian_cosine(rec.normal, to_light); 
                    if (cosine > 0 && diffuse != 0){
                        ray shadow = shadow_ray_make(rec, to_light);
                        if (scene_occluded(spheres, sphere_count, shadow, f_scale / 1000, INT32_MAX)){
                            cosine = 0;
                        }
                    }
                    return lambertian_shade(albedo, cosine, ambient, diffuse);
        }
        const vec3 unit_direction = vec3_unit_vector(r.dir);
        const fpm_t t = fpm_add(unit_direction.e[1], f_scale) / 2;
        return vec3_add(vec3_scale(white, fpm_sub(f_scale, t)), vec3_scale(blue, t));
    }

static inline vec3 ray_color_trace(ray r, const sphere* spheres, int32_t sphere_count,
    const material* materials, vec3 to_light, fpm_t ambient, fpm_t diffuse){
        hit_record rec;
        vec3 weight = vec3_make(f_scale, f_scale, f_scale);
        const vec3 white = vec3_make(f_scale, f_scale, f_scale);
        const vec3 blue = vec3_make(f_scale / 2, 7 * f_scale / 10, f_scale);
        for (int32_t bounce = 0; bounce <= 2; ++bounce){
            if (scene_hit(spheres, sphere_count, r, f_scale / 1000, INT32_MAX, &rec)) {
                const material mat = materials[rec.material_id];
                if (mat.is_mirror) {
                    if (bounce == 2) {
                        return vec3_make(0, 0, 0);
                    }
                    weight = vec3_mul(weight, mat.albedo);
                    r = reflected_ray_make(r, rec);
                    continue;
                }                
                fpm_t cosine = lambertian_cosine(rec.normal, to_light); 
                if (cosine > 0 && diffuse != 0){
                    ray shadow = shadow_ray_make(rec, to_light);
                    if (scene_occluded(spheres, sphere_count, shadow, f_scale / 1000, INT32_MAX)){
                        cosine = 0;
                    }
                }
                const vec3 color = lambertian_shade(mat.albedo, cosine, ambient, diffuse);
                return vec3_mul(weight, color);
            }
            const vec3 unit_direction = vec3_unit_vector(r.dir);
            const fpm_t t = fpm_add(unit_direction.e[1], f_scale) / 2;
            const vec3 background = vec3_add(vec3_scale(white, fpm_sub(f_scale, t)), vec3_scale(blue, t));
            return vec3_mul(weight, background);
            
        }
        return vec3_make(0, 0, 0);
    }

static inline vec3 ray_color_path(ray r, const sphere* spheres, int32_t sphere_count,
    const path_material *materials, int32_t max_depth, uint32_t *state){
        hit_record rec = {
            vec3_make(0, 0, 0),
            vec3_make(0, 0, 0),
            0, 0, false
        };
        vec3 weight = vec3_make(f_scale, f_scale, f_scale);
        for (int32_t bounce = 0; bounce < max_depth; ++bounce){
            if (scene_hit(spheres, sphere_count, r,f_scale / 1000, INT32_MAX, &rec)){
                const path_material mat = materials[rec.material_id];
                const path_scatter_result scatter = path_material_scatter(mat, r.dir, rec.normal, rec.front_face, state);
                if (!scatter.scattered) return vec3_make(0, 0, 0);
                weight = vec3_mul(weight, scatter.attenuation);
                r = scattered_ray_make(rec, scatter.direction, mat.kind == material_dielectric);
                continue;
            }
            vec3 direction = r.dir;
            uint32_t max_abs = sphere_component_scale(direction);
            if (max_abs == 0) return vec3_make(0, 0, 0);
            while (max_abs < f_scale / 2){
                direction = vec3_add(direction, direction);
                max_abs += max_abs;
            }
            const vec3 unit_direction = vec3_unit_vector(direction);
            const fpm_t t = fpm_add(unit_direction.e[1], f_scale) / 2;
            const vec3 white = vec3_make(f_scale, f_scale, f_scale);
            const vec3 blue = vec3_make(f_scale / 2, 7 * f_scale / 10, f_scale);
            const vec3 background = vec3_add(vec3_scale(white, fpm_sub(f_scale, t)), vec3_scale(blue, t));
            return vec3_mul(weight, background);
        }
        return vec3_make(0, 0, 0);
    }

#endif
