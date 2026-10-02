#ifndef VEC3_H
#define VEC3_H
#include "fpm.h"



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
    return fpm_sqrt(length_squared());
  }

  fpm_t length_squared() const {
    return fpm_mul(e[0], e[0]) + fpm_mul(e[1], e[1]) + fpm_mul(e[2], e[2]);
  }

};

using point3 = vec3;

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




#endif
