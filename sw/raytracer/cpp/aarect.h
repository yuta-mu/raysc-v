#ifndef AARECT_H
#define AARECT_H

#include "hittable.h"

class xy_rect: public hittable {
public:
    xy_rect() {}

    xy_rect(fpm_t _x0, fpm_t _x1, fpm_t _y0, fpm_t _y1, fpm_t _k, shared_ptr<material> mat)
        : x0(_x0), x1(_x1), y0(_y0), y1(_y1), k(_k), mp(mat) {};

    virtual bool hit(const ray& r, fpm_t t0, fpm_t t1, hit_record& rec) const;

    virtual bool bounding_box(fpm_t, fpm_t, aabb& output_box) const {
        output_box = aabb(point3(x0,y0, k-f_scale / 10000), point3(x1, y1, k+f_scale / 10000));
        return true;
    }

public:
    fpm_t x0, x1, y0, y1, k;
    shared_ptr<material> mp;
};

class xz_rect: public hittable {
public:
    xz_rect() {}

    xz_rect(fpm_t _x0, fpm_t _x1, fpm_t _z0, fpm_t _z1, fpm_t _k, shared_ptr<material> mat)
        : x0(_x0), x1(_x1), z0(_z0), z1(_z1), k(_k), mp(mat) {};

    virtual bool hit(const ray& r, fpm_t t0, fpm_t t1, hit_record& rec) const;

    virtual bool bounding_box(fpm_t, fpm_t, aabb& output_box) const {
        output_box = aabb(point3(x0,k-f_scale / 10000,z0), point3(x1, k+f_scale / 10000, z1));
        return true;
    }

public:
    fpm_t x0, x1, z0, z1, k;
    shared_ptr<material> mp;
};

class yz_rect: public hittable {
public:
    yz_rect() {}

    yz_rect(fpm_t _y0, fpm_t _y1, fpm_t _z0, fpm_t _z1, fpm_t _k, shared_ptr<material> mat)
        : y0(_y0), y1(_y1), z0(_z0), z1(_z1), k(_k), mp(mat) {};

    virtual bool hit(const ray& r, fpm_t t0, fpm_t t1, hit_record& rec) const;

    virtual bool bounding_box(fpm_t, fpm_t, aabb& output_box) const {
        output_box = aabb(point3(k-f_scale / 10000, y0, z0), point3(k+f_scale / 10000, y1, z1));
        return true;
    }

public:
    fpm_t y0, y1, z0, z1, k;
    shared_ptr<material> mp;
};

inline bool xy_rect::hit(const ray& r, fpm_t t0, fpm_t t1, hit_record& rec) const {
    if (r.direction().z() == 0 || x0 >= x1 || y0 >= y1) return false;
    auto t = fpm_div_clamped(k-r.origin().z(), r.direction().z());
    if (t <= -infinity || t >= infinity || t < t0 || t > t1)
        return false;
    aabb bounds;
    bounding_box(r.time(), r.time(), bounds);
    if (!bounds.hit(r, t, t)) return false;
    auto x = r.origin().x() + fpm_mul(t, r.direction().x());
    auto y = r.origin().y() + fpm_mul(t, r.direction().y());
    if (x < x0 || x > x1 || y < y0 || y > y1)
        return false;
    rec.u = fpm_div(x-x0, x1-x0);
    rec.v = fpm_div(y-y0, y1-y0);
    rec.t = t;
    auto outward_normal = vec3(0, 0, f_scale);
    rec.set_face_normal(r, outward_normal);
    rec.mat_ptr = mp;
    rec.p = r.at(t);
    return true;
}

inline bool xz_rect::hit(const ray& r, fpm_t t0, fpm_t t1, hit_record& rec) const {
    if (r.direction().y() == 0 || x0 >= x1 || z0 >= z1) return false;
    auto t = fpm_div_clamped(k-r.origin().y(), r.direction().y());
    if (t <= -infinity || t >= infinity || t < t0 || t > t1)
        return false;
    aabb bounds;
    bounding_box(r.time(), r.time(), bounds);
    if (!bounds.hit(r, t, t)) return false;
    auto x = r.origin().x() + fpm_mul(t, r.direction().x());
    auto z = r.origin().z() + fpm_mul(t, r.direction().z());
    if (x < x0 || x > x1 || z < z0 || z > z1)
        return false;
    rec.u = fpm_div(x-x0, x1-x0);
    rec.v = fpm_div(z-z0, z1-z0);
    rec.t = t;
    auto outward_normal = vec3(0, f_scale, 0);
    rec.set_face_normal(r, outward_normal);
    rec.mat_ptr = mp;
    rec.p = r.at(t);
    return true;
}

inline bool yz_rect::hit(const ray& r, fpm_t t0, fpm_t t1, hit_record& rec) const {
    if (r.direction().x() == 0 || y0 >= y1 || z0 >= z1) return false;
    auto t = fpm_div_clamped(k-r.origin().x(), r.direction().x());
    if (t <= -infinity || t >= infinity || t < t0 || t > t1)
        return false;
    aabb bounds;
    bounding_box(r.time(), r.time(), bounds);
    if (!bounds.hit(r, t, t)) return false;
    auto y = r.origin().y() + fpm_mul(t, r.direction().y());
    auto z = r.origin().z() + fpm_mul(t, r.direction().z());
    if (y < y0 || y > y1 || z < z0 || z > z1)
        return false;
    rec.u = fpm_div(y-y0, y1-y0);
    rec.v = fpm_div(z-z0, z1-z0);
    rec.t = t;
    auto outward_normal = vec3(f_scale, 0, 0);
    rec.set_face_normal(r, outward_normal);
    rec.mat_ptr = mp;
    rec.p = r.at(t);
    return true;
}

#endif
