#ifndef HITTABLE_H
#define HITTABLE_H

#include "rtweekend.h"
#include "ray.h"
#include "aabb.h"

class material;

struct hit_record {
    point3 p;
    vec3 normal;
    shared_ptr<material> mat_ptr;
    fpm_t t;
    fpm_t u = 0;
    fpm_t v = 0;
    bool front_face;

    inline void set_face_normal(const ray& r, const vec3& outward_normal) {
        front_face = dot(r.direction(), outward_normal) < 0;
        normal = front_face ? outward_normal :-outward_normal;
    }
};

class hittable {
public:
    virtual ~hittable() {}
    virtual bool hit(
        const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec
    )   const = 0;
    virtual bool bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const = 0;
};

class translate : public hittable {
public:
    translate(shared_ptr<hittable> p, const vec3& displacement)
        : ptr(p), offset(displacement) {}

    virtual bool hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const;
    virtual bool bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const;

public:
    shared_ptr<hittable> ptr;
    vec3 offset;
};

inline bool translate::hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const {
    ray moved_r(r.origin() - offset, r.direction(), r.time());
    if (!ptr->hit(moved_r, t_min, t_max, rec)) return false;
    rec.p += offset;
    return true;
}

inline bool translate::bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const {
    if (!ptr->bounding_box(t0, t1, output_box)) return false;
    output_box = aabb(output_box.min() + offset, output_box.max() + offset);
    return true;
}

class rotate_y : public hittable {
public:
    rotate_y(shared_ptr<hittable> p, fpm_t angle);

    virtual bool hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const;
    virtual bool bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const;

public:
    shared_ptr<hittable> ptr;
    fpm_t sin_theta;
    fpm_t cos_theta;
};

inline rotate_y::rotate_y(shared_ptr<hittable> p, fpm_t angle) : ptr(p) {
    auto radians = degrees_to_radians(angle);
    sin_theta = fpm_sin(radians);
    cos_theta = fpm_cos(radians);
}

inline bool rotate_y::bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const {
    aabb source_box;
    if (!ptr->bounding_box(t0, t1, source_box)) return false;

    point3 min( infinity,  infinity,  infinity);
    point3 max(-infinity, -infinity, -infinity);
    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
            for (int k = 0; k < 2; k++) {
                auto x = i ? source_box.max().x() : source_box.min().x();
                auto y = j ? source_box.max().y() : source_box.min().y();
                auto z = k ? source_box.max().z() : source_box.min().z();
                vec3 tester(fpm_mul(cos_theta, x) + fpm_mul(sin_theta, z), y,
                            -fpm_mul(sin_theta, x) + fpm_mul(cos_theta, z));
                for (int c = 0; c < 3; c++) {
                    min[c] = std::min(min[c], tester[c]);
                    max[c] = std::max(max[c], tester[c]);
                }
            }
        }
    }
    output_box = aabb(min, max);
    return true;
}

inline bool rotate_y::hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const {
    auto origin = r.origin();
    auto direction = r.direction();
    origin[0] = fpm_mul(cos_theta, r.origin()[0]) - fpm_mul(sin_theta, r.origin()[2]);
    origin[2] = fpm_mul(sin_theta, r.origin()[0]) + fpm_mul(cos_theta, r.origin()[2]);
    direction[0] = fpm_mul(cos_theta, r.direction()[0]) - fpm_mul(sin_theta, r.direction()[2]);
    direction[2] = fpm_mul(sin_theta, r.direction()[0]) + fpm_mul(cos_theta, r.direction()[2]);

    ray rotated_r(origin, direction, r.time());
    if (!ptr->hit(rotated_r, t_min, t_max, rec)) return false;

    auto p = rec.p;
    auto normal = rec.normal;
    p[0] = fpm_mul(cos_theta, rec.p[0]) + fpm_mul(sin_theta, rec.p[2]);
    p[2] = -fpm_mul(sin_theta, rec.p[0]) + fpm_mul(cos_theta, rec.p[2]);
    normal[0] = fpm_mul(cos_theta, rec.normal[0]) + fpm_mul(sin_theta, rec.normal[2]);
    normal[2] = -fpm_mul(sin_theta, rec.normal[0]) + fpm_mul(cos_theta, rec.normal[2]);
    rec.p = p;
    rec.normal = normal;
    return true;
}

class flip_face : public hittable {
public:
    flip_face(shared_ptr<hittable> p) : ptr(p) {}

    virtual bool hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const {
        if (!ptr->hit(r, t_min, t_max, rec)) return false;
        rec.front_face = !rec.front_face;
        return true;
    }

    virtual bool bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const {
        return ptr->bounding_box(t0, t1, output_box);
    }

public:
    shared_ptr<hittable> ptr;
};

#endif
