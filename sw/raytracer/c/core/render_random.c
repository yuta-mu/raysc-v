#include "color.h"
#include "image.h"
#include "output.h"
#include "random_scene.h"
#include "render.h"

#ifndef RENDER_SEED
#define RENDER_SEED 20261023u
#endif
#ifndef RENDER_SUBPIXELS
#define RENDER_SUBPIXELS 4
#endif
#if RENDER_SUBPIXELS < 1 || RENDER_SUBPIXELS > 8
#error RENDER_SUBPIXELS must be between 1 and 8
#endif
#ifndef RENDER_NORMALS
#define RENDER_NORMALS 0
#endif
#ifndef RENDER_SHADOWS
#define RENDER_SHADOWS 1
#endif
#ifndef RENDER_MIRRORS
#define RENDER_MIRRORS 1
#endif

void render_image(void){
    sphere spheres[random_sphere_capacity];
    material materials[random_sphere_capacity];
    vec3 albedos[random_sphere_capacity];
    const int32_t count = random_scene_make(spheres, materials, RENDER_SEED);
    const camera cam = random_scene_camera(RENDER_WIDTH, RENDER_HEIGHT);
    const vec3 to_light = vec3_unit_vector(vec3_make(-f_scale, f_scale, f_scale));
    const fpm_t ambient = f_scale / 10;
    const fpm_t diffuse = fpm_sub(f_scale, ambient);
    for (int32_t i = 0; i < count; ++i){
        albedos[i] = materials[i].albedo;
    }
    output_ppm_header(RENDER_WIDTH, RENDER_HEIGHT);
    for (int32_t j = RENDER_HEIGHT - 1; j >= 0; --j){
        for (int32_t i = 0; i < RENDER_WIDTH; ++i){
            vec3 sum = vec3_make(0, 0, 0);
            for (int32_t y = 0; y < RENDER_SUBPIXELS; ++y){
                for (int32_t x = 0; x < RENDER_SUBPIXELS; ++x){
                    const fpm_t s = (i * f_scale + (2 * x + 1) * f_scale / (2 * RENDER_SUBPIXELS)) / RENDER_WIDTH;
                    const fpm_t t = (j * f_scale + (2 * y + 1) * f_scale / (2 * RENDER_SUBPIXELS)) / RENDER_HEIGHT;
                    const ray r = camera_get_ray(cam, s, t);
                    const vec3 sample = RENDER_NORMALS
                        ? ray_color(r, spheres, count)
                        : RENDER_MIRRORS
                            ? ray_color_trace(r, spheres, count, materials, to_light, ambient, diffuse)
                            : RENDER_SHADOWS
                                ? ray_color_shadowed(r, spheres, count, albedos, to_light, ambient, diffuse)
                                : ray_color_lit(r, spheres, count, albedos, to_light, ambient, diffuse);
                    sum = vec3_add(sum, sample);
                }
            }
            const int32_t samples = RENDER_SUBPIXELS * RENDER_SUBPIXELS;
            const vec3 pixel_color = vec3_make(sum.e[0] / samples, sum.e[1] / samples, sum.e[2] / samples);
            write_color(pixel_color);
        }
    }
}
