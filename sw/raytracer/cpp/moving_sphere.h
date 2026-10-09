#ifndef MOVING_SPHERE_H
#define MOVING_SPHERE_H

#include "sphere.h"

class moving_sphere : public hittable {
public:
    moving_sphere() : time0(0), time1(0), radius(0) {}
    moving_sphere(point3 cen0, point3 cen1, fpm_t t0, fpm_t t1, fpm_t r, shared_ptr<material> m)
        : center0(cen0), center1(cen1), time0(t0), time1(t1), radius(r), mat_ptr(m)
    {}

    virtual bool hit(const ray& r, fpm_t tmin, fpm_t tmax, hit_record& rec) const;
    virtual bool bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const;

    point3 center(fpm_t time) const;

public:
    point3 center0, center1;
    fpm_t time0, time1;
    fpm_t radius;
    shared_ptr<material> mat_ptr;
};

inline point3 moving_sphere::center(fpm_t time) const {
    if (time0 == time1) return center0;
    return center0 + fpm_div(time - time0, time1 - time0) * (center1 - center0);
}

inline bool moving_sphere::hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const {
    return sphere(center(r.time()), radius, mat_ptr).hit(r, t_min, t_max, rec);
}

inline bool moving_sphere::bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const {
    const fpm_t r = radius < 0 ? -radius : radius;
    const vec3 extent(r, r, r);
    aabb box0(center(t0) - extent, center(t0) + extent);
    aabb box1(center(t1) - extent, center(t1) + extent);
    output_box = surrounding_box(box0, box1);
    return true;
}

#endif
