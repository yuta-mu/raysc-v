#ifndef VEC3_H
#define VEC3_H

#include "../fpm.h"
#include "rtweekend.h"
#include <ostream>

class vec3 {
public:
  fpm_t e[3];
  vec3() : e{0,0,0} {}
  vec3(fpm_t e0, fpm_t e1, fpm_t e2) : e{e0, e1, e2} {}

  fpm_t x() const {return e[0];}
  fpm_t y() const {return e[1];}
  fpm_t z() const {return e[2];}
  vec3 operator-() const {
    return vec3(fpm_sub(0, e[0]), fpm_sub(0, e[1]), fpm_sub(0, e[2]));
  }
  fpm_t operator[](int i) const {return e[i];}
  fpm_t& operator[](int i) {return e[i];}

  vec3& operator+=(const vec3 &v) {
    e[0] = fpm_add(e[0], v.e[0]);
    e[1] = fpm_add(e[1], v.e[1]);
    e[2] = fpm_add(e[2], v.e[2]);
    return *this;
  }

  vec3& operator*=(const fpm_t t) {
    e[0] = fpm_mul(e[0], t);
    e[1] = fpm_mul(e[1], t);
    e[2] = fpm_mul(e[2], t);
    return *this;
  }
  vec3& operator/=(const fpm_t t) {
    const fpm_t inverse = fpm_rcp(t);
    e[0] = fpm_mul(e[0], inverse);
    e[1] = fpm_mul(e[1], inverse);
    e[2] = fpm_mul(e[2], inverse);
    return *this ;
  }

  fpm_t length() const {
    vec3 scaled = *this;
    int halvings = 0;
    const fpm_t limit = 104 * f_scale;
    while (scaled.e[0] > limit || scaled.e[0] < -limit
        || scaled.e[1] > limit || scaled.e[1] < -limit
        || scaled.e[2] > limit || scaled.e[2] < -limit) {
      scaled *= f_scale / 2;
      ++halvings;
    }
    fpm_t result = fpm_sqrt(scaled.length_squared());
    while (halvings > 0){
      result = fpm_add(result, result);
      --halvings;
    }
    return result;
  }

  fpm_t length_squared() const;

  static vec3 random() {
    return vec3(random_fixed(), random_fixed(), random_fixed());
  }

  static vec3 random(fpm_t min, fpm_t max) {
    return vec3(random_fixed(min, max), random_fixed(min, max), random_fixed(min, max));
  }

};

using point3 = vec3;
using color = vec3;

inline std::ostream& operator<<(std::ostream& out, const vec3& v) {
  return out << v.x() << ' ' << v.y() << ' ' << v.z();
}

inline vec3 operator+(const vec3 &u, const vec3 &v) {
  return vec3(fpm_add(u.e[0], v.e[0]),
              fpm_add(u.e[1], v.e[1]),
              fpm_add(u.e[2], v.e[2]));
}


inline vec3 operator-(const vec3 &u, const vec3 &v) {
  return vec3(fpm_sub(u.e[0], v.e[0]),
              fpm_sub(u.e[1], v.e[1]),
              fpm_sub(u.e[2], v.e[2]));
}

inline vec3 operator*(const vec3 &u, const vec3 &v) {
  return vec3(fpm_mul(u.e[0] , v.e[0]), fpm_mul(u.e[1] , v.e[1]), fpm_mul(u.e[2] , v.e[2]));
}

inline vec3 operator*(fpm_t t, const vec3 &v) {
  return vec3(fpm_mul(t,v.e[0]), fpm_mul(t,v.e[1]), fpm_mul(t,v.e[2]));
}

inline vec3 operator*(const vec3 &v, fpm_t t) {
  return vec3(fpm_mul(t,v.e[0]), fpm_mul(t,v.e[1]), fpm_mul(t,v.e[2]));
}

inline vec3 operator/(vec3 v, fpm_t t) {
  const fpm_t inverse = fpm_rcp(t);
  return vec3(fpm_mul(v.e[0],inverse), fpm_mul(v.e[1],inverse), fpm_mul(v.e[2],inverse));
}


inline fpm_t dot(const vec3 &u, const vec3 &v) {
  const uint32_t p0 = static_cast<uint32_t>(fpm_mul(u.e[0], v.e[0]));
  const uint32_t p1 = static_cast<uint32_t>(fpm_mul(u.e[1], v.e[1]));
  const uint32_t p2 = static_cast<uint32_t>(fpm_mul(u.e[2], v.e[2]));
  const uint32_t sum = p0 + p1 + p2;
  if (sum <= INT32_MAX) {
    return static_cast<fpm_t>(sum);
  }
  else {
    return -1 - static_cast<fpm_t>(UINT32_MAX - sum);
  }
}

inline fpm_t vec3::length_squared() const {
  return dot(*this, *this);
}

inline vec3 cross(const vec3 &u, const vec3 &v) {
  return vec3(fpm_sub(fpm_mul(u.e[1], v.e[2]) , fpm_mul(u.e[2], v.e[1])),
              fpm_sub(fpm_mul(u.e[2], v.e[0]) , fpm_mul(u.e[0], v.e[2])),
              fpm_sub(fpm_mul(u.e[0], v.e[1]) , fpm_mul(u.e[1], v.e[0])));
}

inline vec3 unit_vector(vec3 v) {
  const fpm_t limit = 104 * f_scale;
  while (v.e[0] > limit || v.e[0] < -limit
      || v.e[1] > limit || v.e[1] < -limit
      || v.e[2] > limit || v.e[2] < -limit) {
    v = (f_scale / 2) * v;
  }
  const fpm_t inverse_length = fpm_rsqrt(v.length_squared());
  return inverse_length * v;
}

inline vec3 random_in_unit_sphere() {
  while (true) {
    const vec3 p = vec3::random(-f_scale, f_scale);
    const fpm_t squared = p.length_squared();
    if (squared > 0 && squared < f_scale) return p;
  }
}

inline vec3 random_unit_vector() {
  return unit_vector(random_in_unit_sphere());
}

inline vec3 random_in_unit_disk() {
  while (true) {
    const vec3 p(random_fixed(-f_scale, f_scale), random_fixed(-f_scale, f_scale), 0);
    if (p.length_squared() < f_scale) return p;
  }
}

inline vec3 reflect(const vec3& v, const vec3& n) {
  const fpm_t d = dot(v, n);
  return v - fpm_add(d, d) * n;
}

inline vec3 refract(const vec3& uv, const vec3& n, fpm_t ratio) {
  const fpm_t cosine = clamp(dot(-uv, n), 0, f_scale);
  const vec3 parallel = ratio * (uv + cosine * n);
  const vec3 perpendicular = -fpm_sqrt(std::max(0, f_scale - parallel.length_squared())) * n;
  return parallel + perpendicular;
}




#endif
