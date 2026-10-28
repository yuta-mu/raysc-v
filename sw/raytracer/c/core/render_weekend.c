#include "color.h"
#include "image.h"
#include "weekend.h"

#ifndef RENDER_SEED
#define RENDER_SEED 20261023u
#endif
#ifndef RENDER_SAMPLES
#define RENDER_SAMPLES 10
#endif
#ifndef RENDER_DEPTH
#define RENDER_DEPTH 20
#endif
#ifndef RENDER_DEFOCUS
#define RENDER_DEFOCUS 39322
#endif
#if RENDER_SAMPLES < 1 || RENDER_SAMPLES > 4096
#error RENDER_SAMPLES must be between 1 and 4096
#endif
#if RENDER_DEPTH < 1 || RENDER_DEPTH > 100
#error RENDER_DEPTH must be between 1 and 100
#endif
#if RENDER_DEFOCUS < 0 || RENDER_DEFOCUS > 1966080
#error RENDER_DEFOCUS must be between 0 and 1966080
#endif

void render_image(void){
    static weekend_scene scene;
    static bvh tree;
    const weekend_settings settings = {
        RENDER_WIDTH, RENDER_HEIGHT, RENDER_SAMPLES, RENDER_DEPTH, RENDER_SEED, RENDER_DEFOCUS
    };
    path_camera cam;
    weekend_scene_make(&scene, settings.seed);
    if (!weekend_camera_make(&cam, settings) || !bvh_build(&tree, scene.spheres, scene.count)) return;
    uint32_t sampling = random_seed(settings.seed);
    uint32_t checksum = 0;
    output_ppm_header(settings.width, settings.height);
    for (int32_t y = settings.height - 1; y >= 0; --y){
        for (int32_t x = 0; x < settings.width; ++x){
            write_color(weekend_pixel(&scene, &tree, cam, settings, x, y, &sampling, &checksum));
        }
    }
}
