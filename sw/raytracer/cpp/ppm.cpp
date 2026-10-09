#include "rtweekend.h"
#include "color.h"
#include "hittable_list.h"
#include "sphere.h"
#include "material.h"
#include "camera.h"

#include <iostream>
using namespace std;

color ray_color(const ray& r, const hittable& world, int depth) {
    hit_record rec;

    if (depth <= 0)
        return color(0, 0, 0);

    if(world.hit(r, f_scale / 1000, infinity, rec)) {
        ray scattered;
        color attenuation;
        if (rec.mat_ptr->scatter(r, rec, attenuation, scattered))
            return attenuation * ray_color(scattered, world, depth-1);
        return color(0, 0, 0);
    }

    vec3 unit_direction = unit_vector(r.direction());
    const fpm_t t = (unit_direction.y() + f_scale) / 2;
    return (f_scale - t)*color(f_scale, f_scale, f_scale) + t*color(f_scale / 2, 7 * f_scale / 10, f_scale);
}

int main(){
    constexpr fpm_t aspect_ratio = 16 * f_scale / 9;
    const int image_width = 384;
    const int image_height = image_width * 9 / 16;
    const int samples_per_pixel = 100;
    const int max_depth = 50;

    cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    hittable_list world;

    world.add(make_shared<sphere>(
        point3(0, 0, -f_scale), f_scale / 2, make_shared<lambertian>(color(f_scale / 10, f_scale / 5, f_scale / 2))));
    world.add(make_shared<sphere>(
        point3(0, -201 * f_scale / 2, -f_scale), 100 * f_scale, make_shared<lambertian>(color(4 * f_scale / 5, 4 * f_scale / 5, 0))));
    world.add(make_shared<sphere>(
        point3(f_scale, 0, -f_scale), f_scale / 2, make_shared<metal>(color(4 * f_scale / 5, 3 * f_scale / 5, f_scale / 5), 3 * f_scale / 10)));
    world.add(make_shared<sphere>(
        point3(-f_scale, 0, -f_scale), f_scale / 2, make_shared<dielectric>(3 * f_scale / 2)));
    world.add(make_shared<sphere>(
        point3(-f_scale, 0, -f_scale), -9 * f_scale / 20, make_shared<dielectric>(3 * f_scale / 2)));

    point3 lookfrom(3 * f_scale, 3 * f_scale, 2 * f_scale);
    point3 lookat(0, 0, -f_scale);
    vec3 vup(0, f_scale, 0);
    auto dist_to_focus = (lookfrom - lookat).length();
    constexpr fpm_t aperture = 2 * f_scale;

    camera cam(lookfrom, lookat, vup, 20 * f_scale, aspect_ratio, aperture, dist_to_focus);

    for(int j = image_height-1; j >= 0; --j){
        cerr << "\rScanlines remaining:  " << j << ' ' << flush;
        for(int i = 0; i < image_width; ++i){
            color pixel_color(0, 0, 0);
            for (int s = 0; s < samples_per_pixel; ++s) {
               auto u = (i * f_scale + random_fixed()) / (image_width - 1);
               auto v = (j * f_scale + random_fixed()) / (image_height - 1);
               ray r = cam.get_ray(u, v);
               pixel_color += ray_color(r, world, max_depth);
            }
            write_color(std::cout, pixel_color, samples_per_pixel);
        }
    }
    cerr << "\nDone.\n";
}
