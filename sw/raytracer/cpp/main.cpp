#include "color.h"
#include "ray.h"
#include <iostream>

fpm_t hit_sphere(const point3& center, fpm_t radius, const ray& r) {
    const vec3 oc = r.origin() - center;
    const fpm_t a = dot(r.direction(), r.direction());
    const fpm_t half_b = dot(oc, r.direction());
    const fpm_t c = dot(oc, oc) - fpm_mul(radius, radius);
    const fpm_t discriminant = fpm_mul(half_b, half_b) - fpm_mul(a, c);
    if (a == 0 || discriminant < 0) {
        return -f_scale;
    }
    const fpm_t sqrt_d = fpm_sqrt(discriminant);
    fpm_t t = fpm_div(-half_b - sqrt_d, a);
    if (t > 0) {
        return t;
    }
    t = fpm_div(-half_b + sqrt_d, a);
    return t > 0 ? t : -f_scale;
}

color ray_color(const ray& r) {
    const point3 ball_center(0, 0, -f_scale);
    constexpr fpm_t ball_radius = f_scale / 2;
    const fpm_t ball_t = hit_sphere(ball_center, ball_radius, r);
    const point3 ground_center(0, -21 * f_scale / 2, -f_scale);
    constexpr fpm_t ground_radius = 10 * f_scale;
    const fpm_t ground_t = hit_sphere(ground_center, ground_radius, r);

    fpm_t hit_t = ball_t;
    point3 hit_center = ball_center;
    fpm_t hit_radius = ball_radius;
    if (ground_t > 0 && (hit_t <= 0 || ground_t < hit_t)) {
        hit_t = ground_t;
        hit_center = ground_center;
        hit_radius = ground_radius;
    }
    if (hit_t > 0) {
        const vec3 normal = (r.at(hit_t) - hit_center) / hit_radius;
        return color((normal.x() + f_scale) / 2,
                     (normal.y() + f_scale) / 2,
                     (normal.z() + f_scale) / 2);
    }
    const vec3 unit_direction = unit_vector(r.direction());
    const fpm_t t = (unit_direction.y() + f_scale) / 2;
    return (f_scale - t) * color(f_scale, f_scale, f_scale)
        + t * color(f_scale / 2, 7 * f_scale / 10, f_scale);
}


int main() {
    constexpr fpm_t aspect_ratio = 16 * f_scale / 9;
    constexpr int image_width = 384;
    constexpr int image_height = image_width * 9 / 16;

    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    constexpr fpm_t viewport_height = 2 * f_scale;
    constexpr fpm_t viewport_width = 2 * aspect_ratio;
    constexpr fpm_t focal_length = f_scale;
    const point3 origin(0, 0, 0);
    const vec3 horizontal(viewport_width, 0, 0);
    const vec3 vertical(0, viewport_height, 0);
    const point3 lower_left_corner = origin
        - vec3(viewport_width / 2, viewport_height / 2, focal_length);

    fpm_t horizontal_coordinates[image_width];
    for (int i = 0; i < image_width; ++i) {
        horizontal_coordinates[i] = fpm_from_ratio(i, image_width - 1);
    }

    for (int j = image_height - 1; j >= 0; --j) {
        std::cerr << "\rScanlines remaining: " << j << ' ' << std::flush;
        const fpm_t v = fpm_from_ratio(j, image_height - 1);
        const vec3 row_offset = lower_left_corner + v * vertical - origin;
        for (int i = 0; i < image_width; ++i) {
            const fpm_t u = horizontal_coordinates[i];
            const ray r(origin, row_offset + u * horizontal);
            const color pixel_color = ray_color(r);
            write_color(std::cout, pixel_color);
        }
    }

    std::cerr << "\nDone.\n";
    return 0;
}
