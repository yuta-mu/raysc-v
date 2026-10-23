#ifndef CONSTANT_MEDIUM_H
#define CONSTANT_MEDIUM_H

#include "rtweekend.h"
#include "hittable.h"
#include "material.h"
#include "texture.h"
#include <stdexcept>

class constant_medium : public hittable {
public:
  constant_medium(shared_ptr<hittable> b, fpm_t d, shared_ptr<texture> a)
    : boundary(b), phase_function(make_shared<isotropic>(a)), density(d) {
    if (density <= 0) throw std::invalid_argument("Density must be positive.");
  }

  constant_medium(shared_ptr<hittable> b, fpm_t d, const color& a)
    : constant_medium(b, d, make_shared<solid_color>(a)) {}

  virtual bool hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const;

  virtual bool bounding_box(fpm_t t0, fpm_t t1, aabb& output_box) const {
    return boundary->bounding_box(t0, t1, output_box);
  }

public:
  shared_ptr<hittable> boundary;
  shared_ptr<material> phase_function;
  fpm_t density;
};

inline bool constant_medium::hit(const ray& r, fpm_t t_min, fpm_t t_max, hit_record& rec) const {
  hit_record rec1, rec2;
  if (!boundary->hit(r, -infinity, infinity, rec1))
    return false;
  if (rec1.t > infinity - f_scale / 10000
      || !boundary->hit(r, rec1.t + f_scale / 10000, infinity, rec2))
    return false;

  rec1.t = std::max(0, std::max(rec1.t, t_min));
  rec2.t = std::min(rec2.t, t_max);
  if (rec1.t >= rec2.t) return false;

  const auto ray_length = r.direction().length();
  if (ray_length == 0) return false;
  const auto distance_inside_boundary = fpm_mul(rec2.t - rec1.t, ray_length);
  const auto sample = random_fixed();
  if (sample == 0) return false;
  const auto optical_depth = -fpm_log(sample);
  if (density <= f_scale || distance_inside_boundary <= fpm_div(INT32_MAX, density)) {
    if (optical_depth > fpm_mul(density, distance_inside_boundary)) return false;
  }
  const auto hit_distance = fpm_div(optical_depth, density);

  rec.t = rec1.t + fpm_div(hit_distance, ray_length);
  rec.p = r.at(rec.t);
  rec.normal = vec3(f_scale, 0, 0);
  rec.front_face = true;
  rec.mat_ptr = phase_function;
  rec.u = 0;
  rec.v = 0;
  return true;
}

#endif
