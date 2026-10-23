#include "camera.h"
#include "color.h"
#include "render.h"

#ifndef RENDER_NORMALS
#define RENDER_NORMALS 0
#endif
#ifndef RENDER_SHADOWS
#define RENDER_SHADOWS 1
#endif
#ifndef RENDER_MIRRORS
#define RENDER_MIRRORS 1
#endif

int main(void){
    const int image_width = 64;
    const int image_height = 36;
    const fpm_t aspect_ratio = 16 * f_scale / 9;
    sphere spheres[2];
    camera cam;
    spheres[0] = sphere_make(vec3_make(0, 0, -f_scale),f_scale / 2,0);
    spheres[1] = sphere_make(vec3_make(0, -100 * f_scale - f_scale / 2, -f_scale),100 * f_scale,1);
    cam.origin = vec3_make(0,0,0);
    cam.lower_left_corner = vec3_make(-aspect_ratio, -f_scale, -f_scale);
    cam.horizontal = vec3_make(2 * aspect_ratio, 0, 0);
    cam.vertical = vec3_make(0, 2 * f_scale, 0);

    printf("P3\n%d %d\n255\n", image_width, image_height);

    const vec3 albedos[] = {
        vec3_make(7 * f_scale / 10, 3 * f_scale / 10, 3 * f_scale / 10),
        vec3_make(f_scale / 2, f_scale / 2, f_scale / 2)
    };
    const material materials[] = {
        {albedos[0], true},
        {albedos[1], false}
    };
    const vec3 to_light =
        vec3_unit_vector(vec3_make(-f_scale, f_scale, f_scale));
    const fpm_t ambient = f_scale / 10;
    const fpm_t diffuse = fpm_sub(f_scale, ambient);

    for (int j = image_height - 1; j >= 0; --j){
        for (int i = 0; i < image_width; ++i){
            const fpm_t s = (i * f_scale + f_scale / 2) / image_width;
            const fpm_t t = (j * f_scale + f_scale / 2) / image_height;
            const ray r = camera_get_ray(cam, s, t);
            const vec3 pixel_color = RENDER_NORMALS
                ? ray_color(r, spheres, 2)
                : RENDER_MIRRORS
                    ? ray_color_trace(r, spheres, 2, materials, to_light, ambient, diffuse)
                    : RENDER_SHADOWS
                        ? ray_color_shadowed(r, spheres, 2, albedos, to_light, ambient, diffuse)
                        : ray_color_lit(r, spheres, 2, albedos, to_light, ambient, diffuse);
            write_color(stdout, pixel_color);
        }
    }    
}