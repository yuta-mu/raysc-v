#define STB_IMAGE_IMPLEMENTATION
#include "rtw_stb_image.h"
#undef STB_IMAGE_IMPLEMENTATION

#include "rtweekend.h"
#include "aarect.h"
#include "box.h"
#include "bvh.h"
#include "camera.h"
#include "color.h"
#include "constant_medium.h"
#include "hittable_list.h"
#include "material.h"
#include "moving_sphere.h"
#include "sphere.h"
#include "texture.h"
#include <iostream>
#include <cerrno>
#include <cstdlib>
#include <string>

color ray_color(const ray& r, const color& background, const hittable& world, int depth) {
  hit_record rec;

  if (depth <= 0)
    return color(0,0,0);

  if (!world.hit(r, f_scale / 1000, infinity, rec))
    return background;

  ray scattered;
  color attenuation;
  color emitted = rec.mat_ptr->emitted(rec.u, rec.v, rec.p);

  if (!rec.mat_ptr->scatter(r, rec, attenuation, scattered))
    return emitted;

  return emitted + attenuation * ray_color(scattered, background, world, depth-1);
}

hittable_list final_scene(const char* earthmap_filename) {
  hittable_list boxes1;
  auto ground = make_shared<lambertian>(make_shared<solid_color>(12 * f_scale / 25, 83 * f_scale / 100, 53 * f_scale / 100));

  const int boxes_per_side = 20;
  for (int i = 0; i < boxes_per_side; i++) {
    for (int j = 0; j < boxes_per_side; j++) {
      auto w = 100 * f_scale;
      auto x0 = -1000 * f_scale + i*w;
      auto z0 = -1000 * f_scale + j*w;
      auto y0 = 0;
      auto x1 = x0 + w;
      auto y1 = random_fixed(f_scale,101 * f_scale);
      auto z1 = z0 + w;

      boxes1.add(make_shared<box>(point3(x0,y0,z0), point3(x1,y1,z1), ground));
    }
  }

  hittable_list objects;

  objects.add(make_shared<bvh_node>(boxes1, 0, f_scale));

  auto light = make_shared<diffuse_light>(make_shared<solid_color>(7 * f_scale, 7 * f_scale, 7 * f_scale));
  objects.add(make_shared<xz_rect>(123 * f_scale, 423 * f_scale, 147 * f_scale, 412 * f_scale, 554 * f_scale, light));

  auto center1 = point3(400 * f_scale, 400 * f_scale, 200 * f_scale);
  auto center2 = center1 + vec3(30 * f_scale,0,0);
  auto moving_sphere_material =
    make_shared<lambertian>(make_shared<solid_color>(7 * f_scale / 10, 3 * f_scale / 10, f_scale / 10));
  objects.add(make_shared<moving_sphere>(center1, center2, 0, f_scale, 50 * f_scale, moving_sphere_material));

  objects.add(make_shared<sphere>(point3(260 * f_scale, 150 * f_scale, 45 * f_scale), 50 * f_scale, make_shared<dielectric>(3 * f_scale / 2)));
  objects.add(make_shared<sphere>(
                                  point3(0, 150 * f_scale, 145 * f_scale), 50 * f_scale, make_shared<metal>(color(4 * f_scale / 5, 4 * f_scale / 5, 9 * f_scale / 10), 10 * f_scale)
                                  ));

  auto boundary = make_shared<sphere>(point3(360 * f_scale,150 * f_scale,145 * f_scale), 70 * f_scale, make_shared<dielectric>(3 * f_scale / 2));
  objects.add(boundary);
  objects.add(make_shared<constant_medium>(
                                           boundary, f_scale / 5, make_shared<solid_color>(f_scale / 5, 2 * f_scale / 5, 9 * f_scale / 10)
                                           ));
  boundary = make_shared<sphere>(point3(0, 0, 0), 5000 * f_scale, make_shared<dielectric>(3 * f_scale / 2));
  objects.add(make_shared<constant_medium>(
                                           boundary, f_scale / 10000, make_shared<solid_color>(f_scale,f_scale,f_scale)));

  auto emat = make_shared<lambertian>(make_shared<image_texture>(earthmap_filename));
  objects.add(make_shared<sphere>(point3(400 * f_scale,200 * f_scale,400 * f_scale), 100 * f_scale, emat));
  auto pertext = make_shared<noise_texture>(f_scale / 10);
  objects.add(make_shared<sphere>(point3(220 * f_scale,280 * f_scale,300 * f_scale), 80 * f_scale, make_shared<lambertian>(pertext)));

  hittable_list boxes2;
  auto white = make_shared<lambertian>(make_shared<solid_color>(73 * f_scale / 100, 73 * f_scale / 100, 73 * f_scale / 100));
  int ns = 1000;
  for (int j = 0; j < ns; j++) {
    boxes2.add(make_shared<sphere>(point3::random(0,165 * f_scale), 10 * f_scale, white));
  }

  objects.add(make_shared<translate>(
                                     make_shared<rotate_y>(
                                                           make_shared<bvh_node>(boxes2, 0, f_scale), 15 * f_scale),
                                     vec3(-100 * f_scale,270 * f_scale,395 * f_scale)
                                     )
              );

  return objects;
}

hittable_list cornell_smoke() {
  hittable_list objects;

  auto red   = make_shared<lambertian>(make_shared<solid_color>(13 * f_scale / 20, f_scale / 20, f_scale / 20));
  auto white = make_shared<lambertian>(make_shared<solid_color>(73 * f_scale / 100, 73 * f_scale / 100, 73 * f_scale / 100));
  auto green = make_shared<lambertian>(make_shared<solid_color>(3 * f_scale / 25, 9 * f_scale / 20, 3 * f_scale / 20));
  auto light = make_shared<diffuse_light>(make_shared<solid_color>(7 * f_scale, 7 * f_scale, 7 * f_scale));

  objects.add(make_shared<yz_rect>(0, 555 * f_scale, 0, 555 * f_scale, 555 * f_scale, green));
  objects.add(make_shared<yz_rect>(0, 555 * f_scale, 0, 555 * f_scale, 0, red));
  objects.add(make_shared<xz_rect>(113 * f_scale, 443 * f_scale, 127 * f_scale, 432 * f_scale, 554 * f_scale, light));
  objects.add(make_shared<xz_rect>(0, 555 * f_scale, 0, 555 * f_scale, 555 * f_scale, white));
  objects.add(make_shared<xz_rect>(0, 555 * f_scale, 0, 555 * f_scale, 0, white));
  objects.add(make_shared<xy_rect>(0, 555 * f_scale, 0, 555 * f_scale, 555 * f_scale, white));

  shared_ptr<hittable> box1 = make_shared<box>(point3(0,0,0), point3(165 * f_scale,330 * f_scale,165 * f_scale), white);
  box1 = make_shared<rotate_y>(box1,  15 * f_scale);
  box1 = make_shared<translate>(box1, vec3(265 * f_scale,0,295 * f_scale));

  shared_ptr<hittable> box2 = make_shared<box>(point3(0,0,0), point3(165 * f_scale,165 * f_scale,165 * f_scale), white);
  box2 = make_shared<rotate_y>(box2, -18 * f_scale);
  box2 = make_shared<translate>(box2, vec3(130 * f_scale,0,65 * f_scale));

  objects.add(make_shared<constant_medium>(box1, f_scale / 100, make_shared<solid_color>(0,0,0)));
  objects.add(make_shared<constant_medium>(box2, f_scale / 100, make_shared<solid_color>(f_scale,f_scale,f_scale)));

  return objects;
}

hittable_list cornell_box() {
  hittable_list objects;

  auto red   = make_shared<lambertian>(make_shared<solid_color>(13 * f_scale / 20, f_scale / 20, f_scale / 20));
  auto white = make_shared<lambertian>(make_shared<solid_color>(73 * f_scale / 100, 73 * f_scale / 100, 73 * f_scale / 100));
  auto green = make_shared<lambertian>(make_shared<solid_color>(3 * f_scale / 25, 9 * f_scale / 20, 3 * f_scale / 20));
  auto light = make_shared<diffuse_light>(make_shared<solid_color>(15 * f_scale, 15 * f_scale, 15 * f_scale));

  objects.add(make_shared<yz_rect>(0, 555 * f_scale, 0, 555 * f_scale, 555 * f_scale, green));
  objects.add(make_shared<yz_rect>(0, 555 * f_scale, 0, 555 * f_scale, 0, red));
  objects.add(make_shared<xz_rect>(213 * f_scale, 343 * f_scale, 227 * f_scale, 332 * f_scale, 554 * f_scale, light));
  objects.add(make_shared<xz_rect>(0, 555 * f_scale, 0, 555 * f_scale, 0, white));
  objects.add(make_shared<xz_rect>(0, 555 * f_scale, 0, 555 * f_scale, 555 * f_scale, white));
  objects.add(make_shared<xy_rect>(0, 555 * f_scale, 0, 555 * f_scale, 555 * f_scale, white));

  shared_ptr<hittable> box1 = make_shared<box>(point3(0, 0, 0), point3(165 * f_scale, 330 * f_scale, 165 * f_scale), white);
  box1 = make_shared<rotate_y>(box1,  15 * f_scale);
  box1 = make_shared<translate>(box1, vec3(265 * f_scale,0,295 * f_scale));
  objects.add(box1);

  shared_ptr<hittable> box2 = make_shared<box>(point3(0,0,0), point3(165 * f_scale,165 * f_scale,165 * f_scale), white);
  box2 = make_shared<rotate_y>(box2, -18 * f_scale);
  box2 = make_shared<translate>(box2, vec3(130 * f_scale,0,65 * f_scale));
  objects.add(box2);

  return objects;
}

hittable_list simple_light() {
  hittable_list objects;

  auto pertext = make_shared<noise_texture>(4 * f_scale);
  objects.add(make_shared<sphere>(point3(0,-1000 * f_scale,0), 1000 * f_scale, make_shared<lambertian>(pertext)));
  objects.add(make_shared<sphere>(point3(0,2 * f_scale,0), 2 * f_scale, make_shared<lambertian>(pertext)));

  auto difflight = make_shared<diffuse_light>(make_shared<solid_color>(4 * f_scale,4 * f_scale,4 * f_scale));
  objects.add(make_shared<sphere>(point3(0,7 * f_scale,0), 2 * f_scale, difflight));
  objects.add(make_shared<xy_rect>(3 * f_scale, 5 * f_scale, f_scale, 3 * f_scale, -2 * f_scale, difflight));

  return objects;
}

hittable_list earth(const char* earthmap_filename = "sw/raytracer/cpp/earthmap.jpg") {
  auto earth_texture = make_shared<image_texture>(earthmap_filename);
  auto earth_surface = make_shared<lambertian>(earth_texture);
  auto globe = make_shared<sphere>(point3(0,0,0), 2 * f_scale, earth_surface);

  return hittable_list(globe);
}

hittable_list two_perlin_spheres() {
  hittable_list objects;

  auto pertext = make_shared<noise_texture>(5 * f_scale);
  objects.add(make_shared<sphere>(point3(0,-1000 * f_scale,0), 1000 * f_scale, make_shared<lambertian>(pertext)));
  objects.add(make_shared<sphere>(point3(0, 2 * f_scale, 0), 2 * f_scale, make_shared<lambertian>(pertext)));

  return objects;
}

hittable_list two_spheres() {
  hittable_list objects;

  auto checker = make_shared<checker_texture>(
    make_shared<solid_color>(f_scale / 5, 3 * f_scale / 10, f_scale / 10),
    make_shared<solid_color>(9 * f_scale / 10, 9 * f_scale / 10, 9 * f_scale / 10)
  );

  objects.add(make_shared<sphere>(point3(0,-10 * f_scale, 0), 10 * f_scale, make_shared<lambertian>(checker)));
  objects.add(make_shared<sphere>(point3(0, 10 * f_scale, 0), 10 * f_scale, make_shared<lambertian>(checker)));

  return objects;
}

hittable_list random_scene() {
  hittable_list world;

  auto checker = make_shared<checker_texture>(
    make_shared<solid_color>(f_scale / 5, 3 * f_scale / 10, f_scale / 10),
    make_shared<solid_color>(9 * f_scale / 10, 9 * f_scale / 10, 9 * f_scale / 10)
  );
  world.add(make_shared<sphere>(point3(0,-1000 * f_scale,0), 1000 * f_scale, make_shared<lambertian>(checker)));

  for (int a = -11; a < 11; a++) {
    for (int b = -11; b < 11; b++) {
      auto choose_mat = random_fixed();
      point3 center(a * f_scale + fpm_mul(9 * f_scale / 10, random_fixed()), f_scale / 5, b * f_scale + fpm_mul(9 * f_scale / 10, random_fixed()));

      if ((center - vec3(4 * f_scale, f_scale / 5, 0)).length() > 9 * f_scale / 10) {
        shared_ptr<material> sphere_material;

        if (choose_mat < 4 * f_scale / 5) {
          auto albedo = color::random() * color::random();
          sphere_material = make_shared<lambertian>(make_shared<solid_color>(albedo));
          auto center2 = center + vec3(0, random_fixed(0,f_scale / 2), 0);
          world.add(make_shared<moving_sphere>(center, center2, 0, f_scale, f_scale / 5, sphere_material));
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

  auto material2 = make_shared<lambertian>(make_shared<solid_color>(2 * f_scale / 5, f_scale / 5, f_scale / 10));
  world.add(make_shared<sphere>(point3(-4 * f_scale, f_scale, 0), f_scale, material2));

  auto material3 = make_shared<metal>(color(7 * f_scale / 10, 3 * f_scale / 5, f_scale / 2), 0);
  world.add(make_shared<sphere>(point3(4 * f_scale, f_scale, 0), f_scale, material3));

  return hittable_list(make_shared<bvh_node>(world, 0, f_scale));
}

struct render_options {
    int width = 384;
    int samples = 100;
    int depth = 50;
    std::string earthmap = "sw/raytracer/cpp/earthmap.jpg";
};

void print_usage(std::ostream& out) {
    out << "Usage: week2 [--width N] [--samples N] [--depth N] [--earthmap FILE]\n"
        << "Defaults: width=384, samples=100, depth=50, earthmap=sw/raytracer/cpp/earthmap.jpg\n"
        << "Limits: width=4..32767, samples=1..2048, depth=1..256\n";
}

bool parse_positive_int(const char* text, int minimum, int maximum, int& value) {
    char* end = nullptr;
    errno = 0;
    long parsed = std::strtol(text, &end, 10);
    if (errno == ERANGE || end == text || *end != '\0' || parsed < minimum || parsed > maximum)
        return false;
    value = static_cast<int>(parsed);
    return true;
}

int main(int argc, char* argv[]) {
    render_options options;
    for (int i = 1; i < argc; ++i) {
        const std::string argument = argv[i];
        if (argument == "--help") {
            print_usage(std::cout);
            return 0;
        }
        if (i + 1 == argc) {
            print_usage(std::cerr);
            return 1;
        }
        const char* value = argv[++i];
        bool valid = true;
        if (argument == "--width")
            valid = parse_positive_int(value, 4, 32767, options.width);
        else if (argument == "--samples")
            valid = parse_positive_int(value, 1, 2048, options.samples);
        else if (argument == "--depth")
            valid = parse_positive_int(value, 1, 256, options.depth);
        else if (argument == "--earthmap")
            options.earthmap = value;
        else
            valid = false;
        if (!valid) {
            std::cerr << "Invalid option: " << argument << ' ' << value << '\n';
            print_usage(std::cerr);
            return 1;
        }
    }
    {
        image_texture earthmap(options.earthmap.c_str());
        if (!earthmap.loaded()) {
            std::cerr << "Cannot open texture: " << options.earthmap
                      << "\nRun from the repository root or pass --earthmap FILE.\n";
            return 1;
        }
    }

  constexpr fpm_t aspect_ratio = 16 * f_scale / 9;
  const int image_width = options.width;
  const int image_height = image_width * 9 / 16;
  const int samples_per_pixel = options.samples;
  const int max_depth = options.depth;
  const color background(0,0,0);

  std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

  hittable_list world = final_scene(options.earthmap.c_str());

  point3 lookfrom(478 * f_scale, 278 * f_scale, -600 * f_scale);
  point3 lookat(278 * f_scale, 278 * f_scale, 0);
  vec3 vup(0, f_scale, 0);
  constexpr fpm_t dist_to_focus = 10 * f_scale;
  constexpr fpm_t aperture = 0;
  constexpr fpm_t vfov = 40 * f_scale;

  camera cam(lookfrom, lookat, vup, vfov, aspect_ratio, aperture, dist_to_focus, 0, f_scale);

  for (int j = image_height-1; j >= 0; --j) {
    std::cerr << "\rScanlines remaining: " << j << ' ' << std::flush;
    for (int i = 0; i < image_width; ++i) {
      color pixel_color(0, 0, 0);
      for (int s = 0; s < samples_per_pixel; ++s) {
        auto u = (i * f_scale + random_fixed()) / (image_width-1);
        auto v = (j * f_scale + random_fixed()) / (image_height-1);
        ray r = cam.get_ray(u, v);
        pixel_color += ray_color(r, background, world, max_depth);
      }
      write_color(std::cout, pixel_color, samples_per_pixel);
    }
  }

  std::cerr << "\nDone.\n";
  return 0;
}
