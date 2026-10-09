#ifndef VEC3_H
#define VEC3_H
#include "fpm.h"
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
    return vec3(-e[0], -e[1], -e[2]);
  }
  fpm_t operator[](int i) const {return e[i];}
  fpm_t& operator[](int i) {return e[i];}

  vec3& operator+=(const vec3 &v) {
    e[0] += v.e[0];
    e[1] += v.e[1];
    e[2] += v.e[2];
    return *this;
  }

  vec3& operator*=(const fpm_t t) {
    e[0] = fpm_mul(e[0], t);
    e[1] = fpm_mul(e[1], t);
    e[2] = fpm_mul(e[2], t);
    return *this;
  }
  vec3& operator/=(const fpm_t t) {
    e[0] = fpm_div(e[0], t);
    e[1] = fpm_div(e[1], t);
    e[2] = fpm_div(e[2], t);
    return *this ;
  }

  fpm_t length() const {
    const fpm_t scale = std::max(std::abs(e[0]), std::max(std::abs(e[1]), std::abs(e[2])));
    if (scale > 104 * f_scale) {
      const vec3 scaled(fpm_div(e[0], scale), fpm_div(e[1], scale), fpm_div(e[2], scale));
      return fpm_mul(scale, fpm_sqrt(scaled.length_squared()));
    }
    return fpm_sqrt(length_squared());
  }

  fpm_t length_squared() const {
    return fpm_mul(e[0], e[0]) + fpm_mul(e[1], e[1]) + fpm_mul(e[2], e[2]);
  }

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
  return vec3(u.e[0] + v.e[0], u.e[1] + v.e[1], u.e[2] + v.e[2]);
}

inline vec3 operator-(const vec3 &u, const vec3 &v) {
  return vec3(u.e[0] - v.e[0], u.e[1] - v.e[1], u.e[2] - v.e[2]);
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
  return vec3(fpm_div(v.e[0],t), fpm_div(v.e[1],t), fpm_div(v.e[2],t));
}

inline fpm_t dot(const vec3 &u, const vec3 &v) {
  return fpm_mul(u.e[0], v.e[0]) + fpm_mul(u.e[1], v.e[1])
    + fpm_mul(u.e[2], v.e[2]);
}

inline vec3 cross(const vec3 &u, const vec3 &v) {
  return vec3(fpm_mul(u.e[1], v.e[2]) - fpm_mul(u.e[2], v.e[1]),
              fpm_mul(u.e[2], v.e[0]) - fpm_mul(u.e[0], v.e[2]),
              fpm_mul(u.e[0], v.e[1]) - fpm_mul(u.e[1], v.e[0]));
}

inline vec3 unit_vector(vec3 v) {
  fpm_t t = v.length();
  return vec3(fpm_div(v.e[0],t), fpm_div(v.e[1],t), fpm_div(v.e[2],t));
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
  return v - (2 * dot(v, n)) * n;
}

inline vec3 refract(const vec3& uv, const vec3& n, fpm_t ratio) {
  const fpm_t cosine = clamp(dot(-uv, n), 0, f_scale);
  const vec3 parallel = ratio * (uv + cosine * n);
  const vec3 perpendicular = -fpm_sqrt(std::max(0, f_scale - parallel.length_squared())) * n;
  return parallel + perpendicular;
}




#endif
