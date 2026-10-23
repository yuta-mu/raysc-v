#ifndef SPHERE_H
#define SPHERE_H

#include "hittable.h"
#include "vec3.h"

inline void get_sphere_uv(const vec3& p, fpm_t& u, fpm_t& v) {
    const fpm_t phi = fpm_atan2(p.z(), p.x());
    const fpm_t theta = fpm_asin(p.y());
    u = clamp(f_scale - fpm_div(phi + pi, 2 * pi), 0, f_scale);
    v = clamp(fpm_div(theta + 102944, pi), 0, f_scale);
}

class sphere : public hittable {
public:
    sphere() : radius(0) {}
    sphere(point3 cen, fpm_t r, shared_ptr<material> m)
        : center(cen), radius(r), mat_ptr(m) {}

    virtual bool hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const;
    virtual bool bounding_box(fpm_t, fpm_t, aabb& output_box) const {
        const vec3 extent(magnitude(radius), magnitude(radius), magnitude(radius));
        output_box = aabb(center - extent, center + extent);
        return true;
    }

    point3 center;
    fpm_t radius;
    shared_ptr<material> mat_ptr;

private:
    static fpm_t magnitude(fpm_t value) { return value < 0 ? -value : value; }

    static fpm_t component_scale(const vec3& value) {
        return std::max(magnitude(value.x()), std::max(magnitude(value.y()), magnitude(value.z())));
    }

    static fpm_t scaled_length(const vec3& value) {
        const fpm_t scale = component_scale(value);
        if (scale == 0) return 0;
        return fpm_mul(scale, (value / scale).length());
    }

    static fpm_t distance_ratio(fpm_t value, fpm_t positive_divisor) {
        if (magnitude(value) / positive_divisor >= 32768)
            return value < 0 ? -infinity : infinity;
        return fpm_div(value, positive_divisor);
    }
};

inline bool sphere::hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const {
    const fpm_t scale = component_scale(r.direction());
    const fpm_t extent = magnitude(radius);
    if (scale == 0 || extent == 0) return false;

    const vec3 direction = r.direction() / scale;
    const fpm_t a = direction.length_squared();
    const vec3 offset = r.origin() - center;
    const fpm_t projection = fpm_div(dot(offset, direction), a);
    const fpm_t distance = scaled_length(offset - projection * direction);
    if (distance >= extent) return false;

    const fpm_t gap = extent - distance;
    const fpm_t sum = extent + distance;
    fpm_t chord;
    if (sum <= f_scale || gap <= fpm_div(INT32_MAX, sum)) {
        chord = fpm_sqrt(fpm_mul(gap, sum));
    } else {
        const fpm_t ratio = fpm_div(distance, extent);
        chord = fpm_mul(extent, fpm_sqrt(std::max(0, f_scale - fpm_mul(ratio, ratio))));
    }
    chord = fpm_div(chord, fpm_sqrt(a));
    fpm_t t = distance_ratio(-projection - chord, scale);
    if (t <= t_min || t >= t_max) {
        t = distance_ratio(-projection + chord, scale);
        if (t <= t_min || t >= t_max) return false;
    }
    rec.t = t;
    rec.p = r.at(t);
    const vec3 outward_normal = (rec.p - center) / radius;
    rec.set_face_normal(r, outward_normal);
    rec.mat_ptr = mat_ptr;
    get_sphere_uv(outward_normal, rec.u, rec.v);
    return true;
}

#endif
