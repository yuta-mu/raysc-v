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

hittable_list random_scene() {
    hittable_list world;

    auto ground_material = make_shared<lambertian>(color(f_scale / 2, f_scale / 2, f_scale / 2));
    world.add(make_shared<sphere>(point3(0, -1000 * f_scale, 0), 1000 * f_scale, ground_material));

    for(int a = -11; a < 11; a++) {
        for(int b = -11; b < 11; b++) {
            auto choose_mat = random_fixed();
            point3 center(a * f_scale + fpm_mul(9 * f_scale / 10, random_fixed()), f_scale / 5, b * f_scale + fpm_mul(9 * f_scale / 10, random_fixed()));

            if ((center - vec3(4 * f_scale, f_scale / 5, 0)).length() > 9 * f_scale / 10) {
                shared_ptr<material> sphere_material;
                if (choose_mat < 4 * f_scale / 5) {
                    auto albedo = color::random() * color::random();
                    sphere_material = make_shared<lambertian>(albedo);
                    world.add(make_shared<sphere>(center, f_scale / 5, sphere_material));
                } else if (choose_mat < 19 * f_scale / 20) {
                    auto albedo = color::random(f_scale / 2, f_scale);
                    auto fuzz = random_fixed(0, f_scale / 2);
                    sphere_material = make_shared<metal>(albedo, fuzz);
                    world.add(make_shared<sphere>(center, f_scale / 5, sphere_material));
                } else {
                    sphere_material = make_shared<dielectric>(3 * f_scale / 2);
                    world.add(make_shared<sphere>(center, f_scale / 5, sphere_material));
                }
            }
        }
    }

    auto material1 = make_shared<dielectric>(3 * f_scale / 2);
    world.add(make_shared<sphere>(point3(0, f_scale, 0), f_scale, material1));
    auto material2 = make_shared<lambertian>(color(2 * f_scale / 5, f_scale / 5, f_scale / 10));
    world.add(make_shared<sphere>(point3(-4 * f_scale, f_scale, 0), f_scale, material2));
    auto material3 = make_shared<metal>(color(7 * f_scale / 10, 3 * f_scale / 5, f_scale / 2), 0);
    world.add(make_shared<sphere>(point3(4 * f_scale, f_scale, 0), f_scale, material3));

    return world;
}

int main(){
    constexpr fpm_t aspect_ratio = 16 * f_scale / 9;
    const int image_width = 384;
    const int image_height = image_width * 9 / 16;
    const int samples_per_pixel = 100;
    const int max_depth = 50;

    cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    auto world = random_scene();

    point3 lookfrom(13 * f_scale, 2 * f_scale, 3 * f_scale);
    point3 lookat(0, 0, 0);
    vec3 vup(0, f_scale, 0);
    constexpr fpm_t dist_to_focus = 10 * f_scale;
    constexpr fpm_t aperture = f_scale / 10;

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
