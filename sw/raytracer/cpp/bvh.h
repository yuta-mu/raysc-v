#ifndef BVH_H
#define BVH_H

#include "hittable_list.h"
#include <algorithm>
#include <cstddef>
#include <stdexcept>

class bvh_node : public hittable {
public:
    bvh_node() {}

    bvh_node(hittable_list& list, fpm_t time0, fpm_t time1)
        : bvh_node(list.objects, 0, list.objects.size(), time0, time1)
    {}

    bvh_node(std::vector<shared_ptr<hittable>>& objects,
             size_t start, size_t end, fpm_t time0, fpm_t time1);

    virtual bool hit(const ray& r, fpm_t tmin, fpm_t tmax, hit_record& rec) const;
    virtual bool bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const;

public:
    shared_ptr<hittable> left;
    shared_ptr<hittable> right;
    aabb box;
};

inline bool bvh_node::bounding_box(fpm_t, fpm_t, aabb& output_box) const {
    if (!left) return false;
    output_box = box;
    return true;
}

inline bool bvh_node::hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const {
    if (!left || !box.hit(r, t_min, t_max))
        return false;

    if (left == right) return left->hit(r, t_min, t_max, rec);

    bool hit_left = left->hit(r, t_min, t_max, rec);
    bool hit_right = right->hit(r, t_min, hit_left ? rec.t : t_max, rec);

    return hit_left || hit_right;
}

inline bool box_compare(const shared_ptr<hittable> a, const shared_ptr<hittable> b, int axis,
                        fpm_t time0 = 0, fpm_t time1 = 0) {
    aabb box_a;
    aabb box_b;

    if (!a->bounding_box(time0, time1, box_a) || !b->bounding_box(time0, time1, box_b))
        throw std::runtime_error("No bounding box in bvh_node constructor.");

    return box_a.min().e[axis] < box_b.min().e[axis];
}

inline bool box_x_compare (const shared_ptr<hittable> a, const shared_ptr<hittable> b) {
    return box_compare(a, b, 0);
}

inline bool box_y_compare (const shared_ptr<hittable> a, const shared_ptr<hittable> b) {
    return box_compare(a, b, 1);
}

inline bool box_z_compare (const shared_ptr<hittable> a, const shared_ptr<hittable> b) {
    return box_compare(a, b, 2);
}

inline bvh_node::bvh_node(
    std::vector<shared_ptr<hittable>>& objects,
    size_t start, size_t end, fpm_t time0, fpm_t time1
) {
    if (start > end || end > objects.size())
        throw std::out_of_range("Invalid object range in bvh_node constructor.");
    size_t object_span = end - start;
    if (object_span == 0) return;

    int axis = random_int(0,2);
    auto comparator = [axis, time0, time1](const shared_ptr<hittable>& a,
                                         const shared_ptr<hittable>& b) {
        return box_compare(a, b, axis, time0, time1);
    };

    if (object_span == 1) {
        left = right = objects[start];
    } else if (object_span == 2) {
        if (comparator(objects[start], objects[start+1])) {
            left = objects[start];
            right = objects[start+1];
        } else {
            left = objects[start+1];
            right = objects[start];
        }
    } else {
        std::sort(objects.begin() + start, objects.begin() + end, comparator);

        auto mid = start + object_span/2;
        left = make_shared<bvh_node>(objects, start, mid, time0, time1);
        right = make_shared<bvh_node>(objects, mid, end, time0, time1);
    }

    aabb box_left, box_right;

    if (!left->bounding_box(time0, time1, box_left)
        || !right->bounding_box(time0, time1, box_right))
        throw std::runtime_error("No bounding box in bvh_node constructor.");

    box = surrounding_box(box_left, box_right);
}

#endif
