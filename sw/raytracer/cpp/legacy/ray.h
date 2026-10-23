#ifndef RAY_H
#define RAY_H
#include "vec3.h"
class ray {
public:
  ray() : tm(0) {}
  ray(const point3& origin, const vec3& direction, fpm_t time = 0)
    : orig(origin), dir(direction), tm(time) {}

  point3 origin() const  { return orig; }
  vec3 direction() const { return dir; }
  fpm_t time() const { return tm; }

  point3 at(fpm_t t) const {
    return orig + t*dir;
  }

public:
  point3 orig;
  vec3 dir;
  fpm_t tm;
};

#endif
