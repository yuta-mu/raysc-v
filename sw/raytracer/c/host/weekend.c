#include "../core/weekend.h"
#include "../core/color.h"
#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t parse_number(const char* text, uint32_t minimum, uint32_t maximum){
    char* end;
    errno = 0;
    const unsigned long value = strtoul(text, &end, 10);
    if (errno || text == end || *end != '\0' || text[0] == '-' || value < minimum || value > maximum){
        fputs("Invalid render parameter\n", stderr);
        exit(1);
    }
    return (uint32_t)value;
}

static void print_vector(vec3 v){
    printf("%" PRId32 " %" PRId32 " %" PRId32 "\n", v.e[0], v.e[1], v.e[2]);
}

int main(int argc, char** argv){
    if (argc != 7 && argc != 8){
        fputs("usage: weekend WIDTH HEIGHT SAMPLES SEED DEPTH DEFOCUS_RAW [--scene|--linear|--body|--brute]\n", stderr);
        return 1;
    }
    const weekend_settings settings = {
        (int32_t)parse_number(argv[1], 1, 32768), (int32_t)parse_number(argv[2], 1, 32768),
        (int32_t)parse_number(argv[3], 1, 4096), (int32_t)parse_number(argv[5], 1, 100),
        parse_number(argv[4], 0, UINT32_MAX), (fpm_t)parse_number(argv[6], 0, 30 * f_scale)
    };
    const char* mode = argc == 8 ? argv[7] : "";
    if (*mode && strcmp(mode, "--scene") && strcmp(mode, "--linear") && strcmp(mode, "--body") && strcmp(mode, "--brute")) return 1;
    static weekend_scene scene;
    static bvh tree;
    path_camera cam;
    weekend_scene_make(&scene, settings.seed);
    if (!weekend_camera_make(&cam, settings) || !bvh_build(&tree, scene.spheres, scene.count)) return 2;
    if (!strcmp(mode, "--scene")){
        printf("%" PRId32 " %" PRIu32 " %" PRIu32 "\n", scene.count, scene.random.draws, scene.random.state);
        print_vector(cam.view.origin);
        print_vector(cam.view.lower_left_corner);
        print_vector(cam.view.horizontal);
        print_vector(cam.view.vertical);
        print_vector(cam.disk_u);
        print_vector(cam.disk_v);
        for (int32_t i = 0; i < scene.count; ++i){
            print_vector(scene.spheres[i].center);
            printf("%" PRId32 " %d ", scene.spheres[i].radius, (int)scene.materials[i].kind);
            printf("%" PRId32 " %" PRId32 " %" PRId32 " %" PRId32 " %" PRId32 "\n",
                scene.materials[i].albedo.e[0], scene.materials[i].albedo.e[1], scene.materials[i].albedo.e[2],
                scene.materials[i].fuzz, scene.materials[i].ior);
        }
        return fflush(stdout) == EOF;
    }
    const char* first_text = getenv("RT_FIRST_ROW");
    const char* last_text = getenv("RT_LAST_ROW");
    const char* sampling_text = getenv("RT_SAMPLE_STATE");
    const int32_t first = first_text ? (int32_t)parse_number(first_text, 0, (uint32_t)settings.height) : 0;
    const int32_t last = last_text ? (int32_t)parse_number(last_text, 1, (uint32_t)settings.height) : settings.height;
    if (first >= last) return 1;
    uint32_t sampling = sampling_text ? parse_number(sampling_text, 1, UINT32_MAX) : random_seed(settings.seed);
    uint32_t checksum = 0;
    const bool linear = !strcmp(mode, "--linear");
    if (!linear && strcmp(mode, "--body")) output_ppm_header(settings.width, last - first);
    for (int32_t y = settings.height - 1 - first; y >= settings.height - last; --y){
        for (int32_t x = 0; x < settings.width; ++x){
            const vec3 color = weekend_pixel(&scene, !strcmp(mode, "--brute") ? NULL : &tree,
                cam, settings, x, y, &sampling, &checksum);
            if (linear) print_vector(color);
            else write_color(color);
        }
    }
    fprintf(stderr, "{\"primary_state\":%" PRIu32 ",\"path_checksum\":%" PRIu32 "}\n", sampling, checksum);
    return fflush(stdout) == EOF || fflush(stderr) == EOF;
}
