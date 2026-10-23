#ifndef HITTABLE_LIST_H
#define HITTABLE_LIST_H

#include "hittable.h"

#include <memory>
#include <vector>

using namespace std;
using std::shared_ptr;
using std::make_shared;

class hittable_list: public hittable {
public:
    hittable_list() {}
    hittable_list(shared_ptr<hittable> object) { add(object); }

    void clear() { objects.clear(); }
    void add(shared_ptr<hittable> object) { objects.push_back(object); }

    virtual bool hit(
        const ray& r, fpm_t tmin, fpm_t tmax, hit_record& rec
    )  const;
    virtual bool bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const;

public:
    vector<shared_ptr<hittable>> objects;
};

inline bool hittable_list::hit(
    const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec
)   const {
    hit_record temp_rec;
    bool hit_anything = false;
    auto closest_so_far = t_max;

    for (const auto& object : objects) {
        if (object->hit(r, t_min, closest_so_far, temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }

    return hit_anything;
}

inline bool hittable_list::bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const {
    if (objects.empty()) return false;
    aabb temp_box;
    bool first_box = true;
    for (const auto& object : objects) {
        if (!object->bounding_box(t0, t1, temp_box)) return false;
        output_box = first_box ? temp_box : surrounding_box(output_box, temp_box);
        first_box = false;
    }
    return true;
}

#endif
