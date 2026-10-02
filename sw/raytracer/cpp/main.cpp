#include "color.h"
#include "ray.h"
#include <iostream>
#include <cmath>
#include <iostream>
using namespace std;

fpm_t hit_sphere(const point3& center, fpm_t radius, const ray& r) {
    vec3 oc = r.origin() - center;
    auto a = dot(r.direction(), r.direction());
    auto half_b = dot(oc, r.direction());
    auto c = fpm_sub(dot(oc, oc), fpm_mul(radius, radius));
    auto discriminant = fpm_sub(fpm_mul(half_b, half_b), fpm_mul(a, c));
    if (discriminant < 0) {
        return fpm_from_int(-1);
    } 
    auto sqrt_d = fpm_sqrt(discriminant);
    auto t = fpm_div(fpm_sub(fpm_mul(fpm_from_int(-1), half_b), sqrt_d), a);
    if (t > fpm_from_int(0)) {

        return t;
    } 
    else {
        t = fpm_div(fpm_add(fpm_mul(fpm_from_int(-1), half_b), sqrt_d), a);
        return t > fpm_from_int(0) ? t : fpm_from_int(-1);
    }
}

color ray_color(const ray& r) {
    const point3 ball_center(0, 0, fpm_from_int(-1));
    const fpm_t ball_radius = fpm_from_ratio(1, 2);
    fpm_t ball_t = hit_sphere(ball_center, ball_radius, r);
    const point3 ground_center(0, fpm_from_ratio(-21, 2), fpm_from_int(-1));
    const fpm_t ground_radius = fpm_from_int(10);
    fpm_t ground_t = hit_sphere(ground_center, ground_radius, r);
    const fpm_t one = fpm_from_int(1);
    vec3 N;
    if (ball_t > 0){
        N = unit_vector(r.at(ball_t) - ball_center);
        if(ground_t > 0){
            if(ball_t > ground_t){
                N = unit_vector(r.at(ground_t) - ground_center);
            }
        }
        return color(fpm_add(N.x(),one), fpm_add(N.y(),one), fpm_add(N.z(),one))/fpm_from_int(2);
    }
    if(ground_t > 0){
        N = unit_vector(r.at(ground_t) - ground_center);
        return color(fpm_add(N.x(),one), fpm_add(N.y(),one), fpm_add(N.z(),one))/fpm_from_int(2);
    }
    vec3 unit_direction = unit_vector(r.direction());
    auto t = fpm_mul(fpm_from_ratio(1, 2),fpm_add(unit_direction.y() , one));
    return fpm_sub(one, t)*color(one, one, one) + 
        t*color(fpm_from_ratio(1, 2),
        fpm_from_ratio(7, 10),
        one);
};


int main() {
    const auto aspect_ratio =  fpm_from_ratio(16, 9);
    const int image_width = 384;
    const int image_height = image_width * 9 / 16;

    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    auto viewport_height = fpm_from_int(2);
    auto viewport_width = fpm_mul(aspect_ratio, viewport_height);
    auto focal_length = fpm_from_int(1);

    auto origin = point3(0, 0, 0);
    auto horizontal = vec3(viewport_width, 0, 0);
    auto vertical = vec3(0, viewport_height, 0);
    auto lower_left_corner = origin - horizontal/fpm_from_int(2) - vertical/fpm_from_int(2) - vec3(0, 0, focal_length);
    

    for (int j = image_height-1; j >= 0; --j) {
        std::cerr << "\rScanlines remaining: " << j << ' ' << std::flush;
        for (int i = 0; i < image_width; ++i) {
        const fpm_t u = fpm_from_ratio(i, image_width - 1);
        const fpm_t v = fpm_from_ratio(j, image_height - 1);
        ray r(origin, lower_left_corner + u*horizontal + v*vertical - origin);
        color pixel_color = ray_color(r);
        write_color(std::cout, pixel_color);
        }
    }

    std::cerr << "\nDone.\n";
}
