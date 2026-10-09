#ifndef AABB_H
#define AABB_H

#include "ray.h"
#include <utility>

class aabb {
public:
    aabb() {}
    aabb(const point3& a, const point3& b) : _min(a), _max(b) {}

    point3 min() const { return _min; }
    point3 max() const { return _max; }
    bool hit(const ray& r, fpm_t tmin, fpm_t tmax) const;

public:
    point3 _min;
    point3 _max;
};

inline bool aabb::hit(const ray& r, fpm_t tmin, fpm_t tmax) const {
    if (tmax < tmin) return false;
    for (int a = 0; a < 3; a++) {
        if (r.direction()[a] == 0) {
            if (r.origin()[a] < min()[a] || r.origin()[a] > max()[a])
                return false;
            continue;
        }
        auto t0 = fpm_div_clamped(min()[a] - r.origin()[a], r.direction()[a]);
        auto t1 = fpm_div_clamped(max()[a] - r.origin()[a], r.direction()[a]);
        if (r.direction()[a] < 0) std::swap(t0, t1);
        if (t0 > -infinity) --t0;
        if (t1 < infinity) ++t1;
        tmin = t0 > tmin ? t0 : tmin;
        tmax = t1 < tmax ? t1 : tmax;
        if (tmax < tmin) return false;
    }
    return true;
}

inline aabb surrounding_box(aabb box0, aabb box1) {
    point3 small(std::min(box0.min().x(), box1.min().x()),
                 std::min(box0.min().y(), box1.min().y()),
                 std::min(box0.min().z(), box1.min().z()));
    point3 big(std::max(box0.max().x(), box1.max().x()),
               std::max(box0.max().y(), box1.max().y()),
               std::max(box0.max().z(), box1.max().z()));
    return aabb(small, big);
}

#endif
