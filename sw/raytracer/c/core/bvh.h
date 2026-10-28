#ifndef CORE_BVH_H
#define CORE_BVH_H

#include "path_geometry.h"

enum { bvh_sphere_capacity = 488, bvh_node_capacity = 2 * bvh_sphere_capacity - 1 };

typedef struct {
    vec3 minimum;
    vec3 maximum;
    int32_t left;
    int32_t right;
    int32_t object;
} bvh_node;

typedef struct {
    bvh_node nodes[bvh_node_capacity];
    int32_t order[bvh_sphere_capacity];
    int32_t count;
} bvh;

static inline bool bvh_build(bvh* tree, const sphere* spheres, int32_t count){
    if (count < 1 || count > bvh_sphere_capacity) return false;
    struct { int32_t node, first, count; } jobs[32];
    int32_t pending = 1;
    jobs[0].node = 0;
    jobs[0].first = 0;
    jobs[0].count = count;
    tree->count = 1;
    for (int32_t i = 0; i < count; ++i) tree->order[i] = i;
    while (pending > 0){
        --pending;
        const int32_t node = jobs[pending].node;
        const int32_t first = jobs[pending].first;
        const int32_t length = jobs[pending].count;
        vec3 minimum = vec3_make(INT32_MAX, INT32_MAX, INT32_MAX);
        vec3 maximum = vec3_make(INT32_MIN, INT32_MIN, INT32_MIN);
        vec3 center_min = minimum;
        vec3 center_max = maximum;
        for (int32_t j = first; j < first + length; ++j){
            const sphere s = spheres[tree->order[j]];
            if (s.radius <= 0) return false;
            for (int axis = 0; axis < 3; ++axis){
                const fpm_t low = fpm_sub(s.center.e[axis], fpm_add(s.radius, 8));
                const fpm_t high = fpm_add(s.center.e[axis], fpm_add(s.radius, 8));
                if (low < minimum.e[axis]) minimum.e[axis] = low;
                if (high > maximum.e[axis]) maximum.e[axis] = high;
                if (s.center.e[axis] < center_min.e[axis]) center_min.e[axis] = s.center.e[axis];
                if (s.center.e[axis] > center_max.e[axis]) center_max.e[axis] = s.center.e[axis];
            }
        }
        tree->nodes[node].minimum = minimum;
        tree->nodes[node].maximum = maximum;
        tree->nodes[node].left = -1;
        tree->nodes[node].right = -1;
        tree->nodes[node].object = length == 1 ? tree->order[first] : -1;
        if (length == 1) continue;
        int axis = 0;
        for (int i = 1; i < 3; ++i){
            if (fpm_sub(center_max.e[i], center_min.e[i])
                > fpm_sub(center_max.e[axis], center_min.e[axis])) axis = i;
        }
        for (int32_t j = first + 1; j < first + length; ++j){
            const int32_t value = tree->order[j];
            int32_t k = j;
            while (k > first){
                const int32_t previous = tree->order[k - 1];
                if (spheres[previous].center.e[axis] < spheres[value].center.e[axis]
                    || (spheres[previous].center.e[axis] == spheres[value].center.e[axis] && previous < value)) break;
                tree->order[k] = previous;
                --k;
            }
            tree->order[k] = value;
        }
        if (tree->count + 2 > bvh_node_capacity || pending + 2 > 32) return false;
        const int32_t left = tree->count++;
        const int32_t right = tree->count++;
        tree->nodes[node].left = left;
        tree->nodes[node].right = right;
        jobs[pending].node = right;
        jobs[pending].first = first + length / 2;
        jobs[pending++].count = length - length / 2;
        jobs[pending].node = left;
        jobs[pending].first = first;
        jobs[pending++].count = length / 2;
    }
    return true;
}

static inline fpm_t bvh_distance_ratio(fpm_t value, uint32_t divisor){
    if (divisor > f_scale) return sphere_distance_ratio(value, divisor);
    const uint32_t magnitude = sphere_magnitude(value);
    const uint32_t whole = magnitude / divisor;
    if (whole >= 32768u) return value < 0 ? -INT32_MAX : INT32_MAX;
    const uint32_t fraction = ((magnitude % divisor) << 16) / divisor;
    const fpm_t result = (fpm_t)((whole << 16) | fraction);
    return value < 0 ? -result : result;
}

static inline bool bvh_box_hit(bvh_node node, ray r, fpm_t t_min, fpm_t t_max){
    for (int axis = 0; axis < 3; ++axis){
        if (r.dir.e[axis] == 0){
            if (r.orig.e[axis] < node.minimum.e[axis] || r.orig.e[axis] > node.maximum.e[axis]) return false;
            continue;
        }
        const uint32_t magnitude = sphere_magnitude(r.dir.e[axis]);
        fpm_t a = bvh_distance_ratio(fpm_sub(node.minimum.e[axis], r.orig.e[axis]), magnitude);
        fpm_t b = bvh_distance_ratio(fpm_sub(node.maximum.e[axis], r.orig.e[axis]), magnitude);
        if (r.dir.e[axis] < 0){
            const fpm_t swap = a;
            a = fpm_sub(0, b);
            b = fpm_sub(0, swap);
        }
        if (a > t_min) t_min = a;
        if (b < t_max) t_max = b;
        if (t_max < t_min) return false;
    }
    return true;
}

static inline bool bvh_hit(const bvh* tree, const sphere* spheres, ray r,
    fpm_t t_min, fpm_t t_max, hit_record* rec){
    int32_t stack[32];
    int pending = 1;
    stack[0] = 0;
    bool found = false;
    int32_t nearest = INT32_MAX;
    fpm_t closest = t_max;
    while (pending > 0){
        const bvh_node node = tree->nodes[stack[--pending]];
        const fpm_t limit = found && closest < INT32_MAX ? closest + 1 : closest;
        if (!bvh_box_hit(node, r, t_min, limit)) continue;
        if (node.object >= 0){
            hit_record candidate;
            if (path_sphere_hit(spheres[node.object], r, t_min, limit, &candidate)
                && (!found || candidate.t < closest || (candidate.t == closest && node.object < nearest))){
                *rec = candidate;
                closest = candidate.t;
                nearest = node.object;
                found = true;
            }
        } else {
            stack[pending++] = node.right;
            stack[pending++] = node.left;
        }
    }
    return found;
}

#endif
