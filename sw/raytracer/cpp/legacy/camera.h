#ifndef CAMERA_H
#define CAMERA_H

#include "rtweekend.h"
#include "ray.h"

class camera {
public:
    camera(point3 lookfrom, point3 lookat, vec3 vup, fpm_t vfov,
           fpm_t aspect_ratio, fpm_t aperture, fpm_t focus_dist,
           fpm_t t0 = 0, fpm_t t1 = 0) {
        const fpm_t theta = degrees_to_radians(vfov);
        const fpm_t h = fpm_tan(theta / 2);
        const fpm_t viewport_height = 2 * h;
        const fpm_t viewport_width = fpm_mul(aspect_ratio, viewport_height);

        w = unit_vector(lookfrom - lookat);
        u = unit_vector(cross(vup, w));
        v = cross(w, u);
        origin = lookfrom;
        horizontal = fpm_mul(focus_dist, viewport_width) * u;
        vertical = fpm_mul(focus_dist, viewport_height) * v;
        lower_left_corner = origin - horizontal / (2 * f_scale)
                                   - vertical / (2 * f_scale) - focus_dist * w;
        lens_radius = aperture / 2;
        time0 = t0;
        time1 = t1;
    }

    ray get_ray(fpm_t s, fpm_t t) const {
        const vec3 rd = lens_radius * random_in_unit_disk();
        const vec3 offset = u * rd.x() + v * rd.y();
        return ray(origin + offset,
                   lower_left_corner + s * horizontal + t * vertical - origin - offset,
                   time0 == time1 ? time0 : random_fixed(time0, time1));
    }

private:
    point3 origin;
    point3 lower_left_corner;
    vec3 horizontal;
    vec3 vertical;
    vec3 u, v, w;
    fpm_t lens_radius;
    fpm_t time0, time1;
};

#endif
