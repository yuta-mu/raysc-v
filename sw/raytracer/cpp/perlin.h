#ifndef PERLIN_H
#define PERLIN_H

#include "rtweekend.h"
#include "vec3.h"

inline fpm_t perlin_interp(vec3 c[2][2][2], fpm_t u, fpm_t v, fpm_t w) {
  auto uu = fpm_mul(fpm_mul(u, u), 3 * f_scale - 2 * u);
  auto vv = fpm_mul(fpm_mul(v, v), 3 * f_scale - 2 * v);
  auto ww = fpm_mul(fpm_mul(w, w), 3 * f_scale - 2 * w);
  fpm_t accum = 0;

  for (int i=0; i < 2; i++)
    for (int j=0; j < 2; j++)
      for (int k=0; k < 2; k++) {
        vec3 weight_v(u - i * f_scale, v - j * f_scale, w - k * f_scale);
        auto weight = fpm_mul(i ? uu : f_scale - uu, j ? vv : f_scale - vv);
        weight = fpm_mul(weight, k ? ww : f_scale - ww);
        accum += fpm_mul(weight, dot(c[i][j][k], weight_v));
      }

  return accum;
}

class perlin {
public:
  perlin() {
    ranvec = new vec3[point_count];

    for (int i = 0; i < point_count; ++i) {
      vec3 v;
      do {
        v = vec3::random(-f_scale, f_scale);
      } while (v.length_squared() == 0);
      ranvec[i] = unit_vector(v);
    }

    perm_x = perlin_generate_perm();
    perm_y = perlin_generate_perm();
    perm_z = perlin_generate_perm();
  }

  perlin(const perlin&) = delete;
  perlin& operator=(const perlin&) = delete;

  ~perlin() {
    delete[] ranvec;
    delete[] perm_x;
    delete[] perm_y;
    delete[] perm_z;
  }

  fpm_t noise(const point3& p) const {
    int i = p.x() / f_scale - (p.x() % f_scale < 0);
    int j = p.y() / f_scale - (p.y() % f_scale < 0);
    int k = p.z() / f_scale - (p.z() % f_scale < 0);
    auto u = p.x() - i * f_scale;
    auto v = p.y() - j * f_scale;
    auto w = p.z() - k * f_scale;
    vec3 c[2][2][2];

    for (int di=0; di < 2; di++)
      for (int dj=0; dj < 2; dj++)
        for (int dk=0; dk < 2; dk++)
          c[di][dj][dk] = ranvec[
            perm_x[(i+di) & 255] ^
            perm_y[(j+dj) & 255] ^
            perm_z[(k+dk) & 255]
          ];

    return perlin_interp(c, u, v, w);
  }

  fpm_t turb(const point3& p, int depth=7) const {
    fpm_t accum = 0;
    auto temp_p = p;
    fpm_t weight = f_scale;

    for (int i = 0; i < depth && weight != 0; i++) {
      accum += fpm_mul(weight, noise(temp_p));
      weight /= 2;
      for (int c = 0; c < 3; c++)
        temp_p[c] = 2 * (temp_p[c] % (point_count * f_scale));
    }

    return accum < 0 ? -accum : accum;
  }

private:
  static const int point_count = 256;
  vec3* ranvec;
  int* perm_x;
  int* perm_y;
  int* perm_z;

  static int* perlin_generate_perm() {
    auto p = new int[point_count];
    for (int i = 0; i < point_count; i++)
      p[i] = i;
    permute(p, point_count);
    return p;
  }

  static void permute(int* p, int n) {
    for (int i = n-1; i > 0; i--) {
      int target = random_int(0, i);
      int tmp = p[i];
      p[i] = p[target];
      p[target] = tmp;
    }
  }
};

#endif
