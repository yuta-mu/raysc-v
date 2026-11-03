// gcc -O3 main.c -o render_c && ./render_c > golden_c.ppm
// gcc -DGENERATE_SCENE main.c -o gen_scene && ./gen_scene <seed_num>

#include "/home/lyra/raysc-v/ref/qmath.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef int32_t q16;
typedef int32_t i32;

#define Q16_CONST(x)                                                           \
  ((q16)((x) >= 0.0 ? ((x) * 65536.0 + 0.5) : ((x) * 65536.0 - 0.5)))

#define Q16_ZERO ((q16)0)
#define Q16_ONE ((q16)0x00010000)
#define Q16_HALF ((q16)0x00008000)
#define Q16_TWO ((q16)0x00020000)
#define Q16_INF Q16_CONST(32767.0)
#define Q16_PI Q16_CONST(3.1415926535897932385)
#define T_EPS Q16_CONST(0.00390625) /* 1/256 */
#define NEAR_ZERO_EPS Q16_CONST(0.0005)
#define UNIT_MIN_LENSQ Q16_CONST(0.01)

#define MAT_LAMBERTIAN 0
#define MAT_METAL 1
#define MAT_DIELECTRIC 2

#ifndef IMAGE_WIDTH
#define IMAGE_WIDTH 320
#endif
#ifndef IMAGE_HEIGHT
#define IMAGE_HEIGHT 180
#endif
#ifndef SAMPLES_PER_PIXEL
#define SAMPLES_PER_PIXEL 100
#endif
#ifndef MAX_DEPTH
#define MAX_DEPTH 20
#endif
#ifndef SEED
#define SEED 42
#endif

typedef struct {
  q16 x;
  q16 y;
  q16 z;
} vec3;

typedef struct {
  vec3 o;
  vec3 d;
} Ray;

typedef struct {
  vec3 c;
  q16 r;
  q16 r2;
  i32 mat_kind;
  vec3 albedo;
  q16 fuzz_or_ref_idx; /* METAL: fuzz, DIELECTRIC: ref_idx */
} Sphere;

typedef struct {
  i32 hit;
  vec3 p;
  vec3 normal;
  q16 t;
  i32 front_face;
  i32 mat_kind;
  vec3 albedo;
  q16 fuzz_or_ref_idx;
} HitRecord;

typedef struct {
  i32 did_scatter;
  vec3 attenuation;
  Ray scattered;
} ScatterResult;

typedef struct {
  vec3 center;
  vec3 viewport_upper_left;
  vec3 viewport_u;
  vec3 viewport_v;
  vec3 defocus_disk_u;
  vec3 defocus_disk_v;
  i32 use_defocus;
} Camera;

static uint32_t g_rng_state = UINT32_C(42);

#define SPH_INIT(cx, cy, cz, rad, kind, ax, ay, az, param)                     \
  {{Q16_CONST(cx), Q16_CONST(cy), Q16_CONST(cz)},                              \
   Q16_CONST(rad),                                                             \
   Q16_CONST((rad) * (rad)),                                                   \
   (kind),                                                                     \
   {Q16_CONST(ax), Q16_CONST(ay), Q16_CONST(az)},                              \
   Q16_CONST(param)}

#ifdef USE_FULL_SCENE
#include "scene_const.inc"
#else

#define NUM_SPHERES 64
static const Sphere SPHERES[NUM_SPHERES] = {
    SPH_INIT(0.00, 1.00, 0.00, 1.00, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(-4.00, 1.00, 0.00, 1.00, 0, 0.50, 0.90, 1.00, 0.00),
    SPH_INIT(4.00, 1.00, 0.00, 1.00, 1, 0.80, 0.70, 0.60, 0.00),
    SPH_INIT(-5.68, 0.20, -3.72, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(6.86, 0.20, 3.37, 0.20, 1, 0.87, 0.46, 0.47, 0.14),
    SPH_INIT(-7.90, 0.20, -0.49, 0.20, 0, 0.09, 0.09, 0.90, 0.00),
    SPH_INIT(6.19, 0.20, -0.04, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(-8.13, 0.20, -2.10, 0.20, 0, 0.15, 0.90, 0.23, 0.00),
    SPH_INIT(-3.54, 0.20, 1.71, 0.20, 0, 0.86, 0.83, 0.07, 0.00),
    SPH_INIT(7.53, 0.20, 1.77, 0.20, 1, 0.37, 0.90, 0.49, 0.05),
    SPH_INIT(-6.02, 0.20, 0.66, 0.20, 0, 0.87, 0.69, 0.06, 0.00),
    SPH_INIT(1.48, 0.20, 1.55, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(-0.44, 0.20, 2.15, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(7.84, 0.20, -0.29, 0.20, 1, 0.95, 0.46, 0.90, 0.04),
    SPH_INIT(7.96, 0.20, 1.13, 0.20, 0, 0.11, 0.94, 0.51, 0.00),
    SPH_INIT(-7.17, 0.20, 2.23, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(-3.50, 0.20, 3.07, 0.20, 0, 0.88, 0.10, 0.15, 0.00),
    SPH_INIT(-4.94, 0.20, -1.37, 0.20, 0, 0.13, 0.87, 0.65, 0.00),
    SPH_INIT(5.71, 0.20, 1.48, 0.20, 1, 0.28, 0.87, 0.88, 0.14),
    SPH_INIT(-7.55, 0.20, 0.94, 0.20, 0, 0.10, 0.87, 0.16, 0.00),
    SPH_INIT(-4.70, 0.20, 1.25, 0.20, 1, 0.40, 0.89, 0.81, 0.15),
    SPH_INIT(3.31, 0.20, -1.03, 0.20, 0, 0.28, 0.06, 0.92, 0.00),
    SPH_INIT(7.07, 0.20, -3.62, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(1.08, 0.20, -1.13, 0.20, 1, 0.86, 0.82, 0.36, 0.12),
    SPH_INIT(8.13, 0.20, -3.04, 0.20, 0, 0.16, 0.90, 0.74, 0.00),
    SPH_INIT(5.08, 0.20, 0.61, 0.20, 1, 0.42, 0.95, 0.75, 0.16),
    SPH_INIT(-1.92, 0.20, -0.43, 0.20, 1, 0.34, 0.94, 0.60, 0.16),
    SPH_INIT(-7.83, 0.20, 2.91, 0.20, 0, 0.43, 0.16, 0.87, 0.00),
    SPH_INIT(4.38, 0.20, 1.72, 0.20, 1, 0.46, 0.50, 0.95, 0.08),
    SPH_INIT(-1.02, 0.20, 2.72, 0.20, 0, 0.86, 0.09, 0.95, 0.00),
    SPH_INIT(8.38, 0.20, 2.52, 0.20, 0, 0.65, 0.88, 0.10, 0.00),
    SPH_INIT(6.15, 0.20, -1.04, 0.20, 0, 0.13, 0.85, 0.20, 0.00),
    SPH_INIT(-5.80, 0.20, 1.68, 0.20, 1, 0.86, 0.42, 0.58, 0.09),
    SPH_INIT(-0.17, 0.20, -1.50, 0.20, 0, 0.05, 0.82, 0.93, 0.00),
    SPH_INIT(-4.10, 0.20, -3.27, 0.20, 0, 0.77, 0.87, 0.08, 0.00),
    SPH_INIT(1.01, 0.20, -2.68, 0.20, 0, 0.05, 0.86, 0.44, 0.00),
    SPH_INIT(0.61, 0.20, 2.69, 0.20, 0, 0.66, 0.07, 0.91, 0.00),
    SPH_INIT(-1.43, 0.20, 0.39, 0.20, 0, 0.62, 0.92, 0.07, 0.00),
    SPH_INIT(-3.83, 0.20, -1.97, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(6.02, 0.20, 3.76, 0.20, 1, 0.92, 0.61, 0.46, 0.14),
    SPH_INIT(2.36, 0.20, -0.42, 0.20, 1, 0.83, 0.91, 0.42, 0.05),
    SPH_INIT(4.13, 0.20, -2.13, 0.20, 0, 0.87, 0.06, 0.31, 0.00),
    SPH_INIT(-2.05, 0.20, 3.52, 0.20, 0, 0.93, 0.13, 0.37, 0.00),
    SPH_INIT(9.00, 0.20, -3.38, 0.20, 0, 0.06, 0.87, 0.71, 0.00),
    SPH_INIT(1.93, 0.20, 3.07, 0.20, 1, 0.56, 0.93, 0.46, 0.02),
    SPH_INIT(-2.26, 0.20, -2.64, 0.20, 0, 0.49, 0.05, 0.89, 0.00),
    SPH_INIT(-4.48, 0.20, 3.58, 0.20, 1, 0.73, 0.30, 0.91, 0.01),
    SPH_INIT(-1.12, 0.20, 1.67, 0.20, 0, 0.85, 0.06, 0.61, 0.00),
    SPH_INIT(3.47, 0.20, 2.92, 0.20, 0, 0.90, 0.64, 0.09, 0.00),
    SPH_INIT(-2.06, 0.20, 2.73, 0.20, 0, 0.71, 0.90, 0.14, 0.00),
    SPH_INIT(-5.37, 0.20, -2.22, 0.20, 0, 0.54, 0.07, 0.89, 0.00),
    SPH_INIT(6.57, 0.20, 1.91, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(8.94, 0.20, 0.73, 0.20, 0, 0.25, 0.89, 0.09, 0.00),
    SPH_INIT(5.16, 0.20, -0.59, 0.20, 0, 0.85, 0.09, 0.05, 0.00),
    SPH_INIT(7.21, 0.20, 2.52, 0.20, 0, 0.93, 0.87, 0.09, 0.00),
    SPH_INIT(-6.80, 0.20, -1.17, 0.20, 0, 0.64, 0.93, 0.09, 0.00),
    SPH_INIT(0.95, 0.20, -3.45, 0.20, 0, 0.82, 0.88, 0.08, 0.00),
    SPH_INIT(-2.54, 0.20, 0.00, 0.20, 1, 0.93, 0.29, 0.60, 0.14),
    SPH_INIT(-6.16, 0.20, -0.35, 0.20, 0, 0.30, 0.88, 0.04, 0.00),
    SPH_INIT(-8.42, 0.20, -3.22, 0.20, 0, 0.89, 0.05, 0.23, 0.00),
    SPH_INIT(7.48, 0.20, -2.21, 0.20, 0, 0.95, 0.09, 0.37, 0.00),
    SPH_INIT(-7.67, 0.20, -3.01, 0.20, 2, 1.00, 1.00, 1.00, 1.50),
    SPH_INIT(0.35, 0.20, 3.71, 0.20, 0, 0.07, 0.96, 0.87, 0.00),
    SPH_INIT(-7.26, 0.20, -2.18, 0.20, 0, 0.06, 0.24, 0.86, 0.00)};
#endif

static inline void bprint(const i32 byte_val) {
  putchar((int)(byte_val & 0xFF));
}

static inline void print_p6_header(const i32 width, const i32 height) {
  printf("P6\n%d %d\n255\n", (int)width, (int)height);
}

static inline q16 q_add(const q16 a, const q16 b) {
  return (q16)((uint32_t)a + (uint32_t)b);
}

static inline q16 q_sub(const q16 a, const q16 b) {
  return (q16)((uint32_t)a - (uint32_t)b);
}

static inline q16 q_neg(const q16 a) { return (q16)(0U - (uint32_t)a); }

static inline q16 q16_from_i32(const i32 a) { return (q16)((uint32_t)a << 16); }

static inline i32 q16_to_i32(const q16 a) {
  return (i32)floor_div_pow2(sx32((uint32_t)a), 16);
}

static inline q16 q_mul(const q16 a, const q16 b) {
  return (q16)q16_mul((uint32_t)a, (uint32_t)b);
}

static inline q16 q_rcp(const q16 a) { return (q16)q16_rcp((uint32_t)a); }

static inline q16 q_div(const q16 a, const q16 b) { return q_mul(a, q_rcp(b)); }

static inline q16 ratio_i32(const i32 n, const i32 d) {
  const uint32_t raw_numerator = ((uint32_t)n) << 16;
  return (q16)(raw_numerator / (uint32_t)d);
}

static inline q16 q_sqrt(const q16 a) { return (q16)q16_sqrt((uint32_t)a); }

static uint64_t isqrt_u64_floor(uint64_t n) {
  uint64_t x = n;
  uint64_t y = (x + 1U) / 2U;
  while (y < x) {
    x = y;
    y = (x + n / x) / 2U;
  }
  return x;
}

static inline q16 q_rsqrt(const q16 a) {
  uint64_t quotient;
  if (a <= 0) {
    return Q16_ZERO;
  }
  quotient = (UINT64_C(1) << 48) / (uint32_t)a;
  return (q16)isqrt_u64_floor(quotient);
}

static inline q16 q_abs(const q16 a) {
  if (a < Q16_ZERO) {
    return q_neg(a);
  }
  return a;
}

static inline q16 q_min(const q16 a, const q16 b) {
  if (a < b) {
    return a;
  }
  return b;
}

static q16 degrees_to_radians(const q16 degrees) {
  const q16 degrees_pi = q_mul(degrees, Q16_PI);
  return q_mul(degrees_pi, q_rcp(q16_from_i32(180)));
}

static q16 q_tan_small(const q16 x) {
  const q16 x2 = q_mul(x, x);
  const q16 x3 = q_mul(x2, x);
  const q16 x5 = q_mul(x3, x2);
  const q16 term1 = q_mul(x3, q_rcp(q16_from_i32(3)));
  const q16 term2 = q_mul(q_mul(Q16_TWO, x5), q_rcp(q16_from_i32(15)));
  return q_add(q_add(x, term1), term2);
}

static i32 rng_next_i32(void) {
  uint32_t x = g_rng_state;
  x ^= x << 13;
  x ^= (x >> 17) & UINT32_C(0x7FFF);
  x ^= x << 5;
  g_rng_state = x;
  return (i32)(x & UINT32_C(0x7FFFFFFF));
}

static q16 random_q16(void) {
  const i32 r = rng_next_i32();
  return (q16)((r >> 8) & 0x0000FFFF);
}

static q16 random_q16_range(const q16 min_val, const q16 max_val) {
  const q16 span = q_sub(max_val, min_val);
  return q_add(min_val, q_mul(span, random_q16()));
}

static inline vec3 make_vec3(const q16 x, const q16 y, const q16 z) {
  vec3 v;
  v.x = x;
  v.y = y;
  v.z = z;
  return v;
}

static inline vec3 vec3_add(const vec3 u, const vec3 v) {
  return make_vec3(q_add(u.x, v.x), q_add(u.y, v.y), q_add(u.z, v.z));
}

static inline vec3 vec3_sub(const vec3 u, const vec3 v) {
  return make_vec3(q_sub(u.x, v.x), q_sub(u.y, v.y), q_sub(u.z, v.z));
}

static inline vec3 vec3_neg(const vec3 v) {
  return make_vec3(q_neg(v.x), q_neg(v.y), q_neg(v.z));
}

static inline vec3 vec3_mul_elem(const vec3 u, const vec3 v) {
  return make_vec3(q_mul(u.x, v.x), q_mul(u.y, v.y), q_mul(u.z, v.z));
}

static inline vec3 vec3_scale(const vec3 v, const q16 t) {
  return make_vec3(q_mul(v.x, t), q_mul(v.y, t), q_mul(v.z, t));
}

static inline q16 vec3_dot(const vec3 u, const vec3 v) {
  return q_add(q_add(q_mul(u.x, v.x), q_mul(u.y, v.y)), q_mul(u.z, v.z));
}

static inline vec3 vec3_cross(const vec3 u, const vec3 v) {
  return make_vec3(q_sub(q_mul(u.y, v.z), q_mul(u.z, v.y)),
                   q_sub(q_mul(u.z, v.x), q_mul(u.x, v.z)),
                   q_sub(q_mul(u.x, v.y), q_mul(u.y, v.x)));
}

static inline q16 vec3_length_squared(const vec3 v) { return vec3_dot(v, v); }

static inline vec3 vec3_unit(const vec3 v) {
  const q16 lensq = vec3_length_squared(v);
  if (lensq <= Q16_ZERO) {
    return make_vec3(Q16_ZERO, Q16_ONE, Q16_ZERO);
  }
  return vec3_scale(v, q_rsqrt(lensq));
}

static vec3 vec3_unit_big(const vec3 v) {
  vec3 s;
  i32 k;
  s = v;
  for (k = 0; k < 8; k = k + 1) {
    if (vec3_length_squared(s) > Q16_TWO) {
      s = vec3_scale(s, Q16_HALF);
    }
  }
  return vec3_unit(s);
}

static inline i32 vec3_near_zero(const vec3 v) {
  if (q_abs(v.x) >= NEAR_ZERO_EPS) {
    return 0;
  }
  if (q_abs(v.y) >= NEAR_ZERO_EPS) {
    return 0;
  }
  if (q_abs(v.z) >= NEAR_ZERO_EPS) {
    return 0;
  }
  return 1;
}

static vec3 random_unit_vector(void) {
  i32 iter;
  q16 rx;
  q16 ry;
  q16 rz;
  vec3 p;
  q16 lensq;
  for (iter = 0; iter < 64; iter = iter + 1) {
    rx = random_q16_range(q_neg(Q16_ONE), Q16_ONE);
    ry = random_q16_range(q_neg(Q16_ONE), Q16_ONE);
    rz = random_q16_range(q_neg(Q16_ONE), Q16_ONE);
    p = make_vec3(rx, ry, rz);
    lensq = vec3_length_squared(p);
    if (lensq >= UNIT_MIN_LENSQ && lensq <= Q16_ONE) {
      return vec3_scale(p, q_rsqrt(lensq));
    }
  }
  return make_vec3(Q16_ZERO, Q16_ONE, Q16_ZERO);
}

static vec3 random_in_unit_disk(void) {
  i32 iter;
  q16 rx;
  q16 ry;
  vec3 p;
  for (iter = 0; iter < 64; iter = iter + 1) {
    rx = random_q16_range(q_neg(Q16_ONE), Q16_ONE);
    ry = random_q16_range(q_neg(Q16_ONE), Q16_ONE);
    p = make_vec3(rx, ry, Q16_ZERO);
    if (vec3_length_squared(p) < Q16_ONE) {
      return p;
    }
  }
  return make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
}

static inline vec3 vec3_reflect(const vec3 v, const vec3 n) {
  const q16 two_dn = q_mul(Q16_TWO, vec3_dot(v, n));
  return vec3_sub(v, vec3_scale(n, two_dn));
}

static inline vec3 vec3_refract(const vec3 uv, const vec3 n,
                                const q16 etai_over_etat) {
  const q16 cos_theta = q_min(vec3_dot(vec3_neg(uv), n), Q16_ONE);
  const vec3 r_out_perp =
      vec3_scale(vec3_add(uv, vec3_scale(n, cos_theta)), etai_over_etat);
  const q16 perp_len2 = vec3_length_squared(r_out_perp);
  const q16 parallel_mag = q_sqrt(q_abs(q_sub(Q16_ONE, perp_len2)));
  const vec3 r_out_parallel = vec3_scale(n, q_neg(parallel_mag));
  return vec3_add(r_out_perp, r_out_parallel);
}

static inline Ray make_ray(const vec3 orig, const vec3 dir) {
  Ray r;
  r.o = orig;
  r.d = vec3_unit(dir);
  return r;
}

static inline vec3 ray_at(const Ray r, const q16 t) {
  return vec3_add(r.o, vec3_scale(r.d, t));
}

static HitRecord hit_ground(const Ray r, const q16 t_min, const q16 t_max) {
  HitRecord rec;
  vec3 os;
  q16 bs;
  q16 ks;
  q16 disc;
  q16 tau;
  q16 root;
  vec3 p;
  vec3 outward_normal;

  rec.hit = 0;
  rec.p = make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
  rec.normal = make_vec3(Q16_ZERO, Q16_ONE, Q16_ZERO);
  rec.t = Q16_ZERO;
  rec.front_face = 1;
  rec.mat_kind = MAT_LAMBERTIAN;
  rec.albedo = make_vec3(Q16_HALF, Q16_HALF, Q16_HALF);
  rec.fuzz_or_ref_idx = Q16_ZERO;

  os = vec3_scale(r.o, Q16_CONST(0.125));
  bs = q_add(vec3_dot(os, r.d), q_mul(Q16_CONST(125.0), r.d.y));
  if (bs >= Q16_ZERO) {
    return rec;
  }

  ks = q_add(vec3_dot(os, os), q_mul(Q16_CONST(31.25), r.o.y));
  disc = q_sub(q_mul(bs, bs), ks);
  if (disc < Q16_ZERO) {
    return rec;
  }

  tau = q_sub(q_neg(bs), q_sqrt(disc));
  root = q_mul(tau, Q16_CONST(8.0));
  if (root <= t_min || root >= t_max) {
    return rec;
  }

  p = ray_at(r, root);
  outward_normal =
      vec3_unit(make_vec3(q_mul(p.x, Q16_CONST(0.001)),
                          q_add(Q16_ONE, q_mul(p.y, Q16_CONST(0.001))),
                          q_mul(p.z, Q16_CONST(0.001))));

  rec.hit = 1;
  rec.t = root;
  rec.p = p;
  rec.normal = outward_normal;
  return rec;
}

static HitRecord hit_sphere(const Sphere s, const Ray r, const q16 t_min,
                            const q16 t_max) {
  HitRecord rec;
  vec3 oc;
  q16 b;
  vec3 perp;
  q16 disc;
  q16 sqrtd;
  q16 root;
  vec3 n;

  rec.hit = 0;
  rec.p = make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
  rec.normal = make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
  rec.t = Q16_ZERO;
  rec.front_face = 0;
  rec.mat_kind = s.mat_kind;
  rec.albedo = s.albedo;
  rec.fuzz_or_ref_idx = s.fuzz_or_ref_idx;

  oc = vec3_sub(r.o, s.c);
  b = vec3_dot(oc, r.d);

  if (b >= s.r) {
    return rec;
  }

  perp = vec3_sub(oc, vec3_scale(r.d, b));
  if (q_abs(perp.x) > s.r || q_abs(perp.y) > s.r || q_abs(perp.z) > s.r) {
    return rec;
  }

  disc = q_sub(s.r2, vec3_length_squared(perp));
  if (disc < Q16_ZERO) {
    return rec;
  }

  sqrtd = q_sqrt(disc);
  root = q_sub(q_neg(b), sqrtd);
  if (root <= t_min || root >= t_max) {
    if (s.mat_kind != MAT_DIELECTRIC) {
      return rec;
    }
    root = q_add(q_neg(b), sqrtd);
    if (root <= t_min || root >= t_max) {
      return rec;
    }
  }

  n = vec3_unit(vec3_sub(ray_at(r, root), s.c));

  rec.hit = 1;
  rec.t = root;
  rec.p = vec3_add(s.c, vec3_scale(n, s.r));
  if (vec3_dot(r.d, n) < Q16_ZERO) {
    rec.front_face = 1;
    rec.normal = n;
  } else {
    rec.front_face = 0;
    rec.normal = vec3_neg(n);
  }
  return rec;
}

static HitRecord world_hit(const Ray r, const q16 t_min, const q16 t_max) {
  HitRecord best_rec;
  HitRecord temp_rec;
  q16 closest_so_far;
  i32 i;

  best_rec = hit_ground(r, t_min, t_max);
  closest_so_far = t_max;
  if (best_rec.hit != 0) {
    closest_so_far = best_rec.t;
  }

  for (i = 0; i < NUM_SPHERES; i = i + 1) {
    temp_rec = hit_sphere(SPHERES[i], r, t_min, closest_so_far);
    if (temp_rec.hit != 0) {
      closest_so_far = temp_rec.t;
      best_rec = temp_rec;
    }
  }
  return best_rec;
}

static q16 schlick_reflectance(const q16 cosine, const q16 refraction_index) {
  const q16 r0_num = q_sub(Q16_ONE, refraction_index);
  const q16 r0_den = q_add(Q16_ONE, refraction_index);
  const q16 r0_base = q_div(r0_num, r0_den);
  const q16 r0 = q_mul(r0_base, r0_base);
  const q16 one_minus_cos = q_sub(Q16_ONE, cosine);
  const q16 c2 = q_mul(one_minus_cos, one_minus_cos);
  const q16 c4 = q_mul(c2, c2);
  const q16 c5 = q_mul(c4, one_minus_cos);
  return q_add(r0, q_mul(q_sub(Q16_ONE, r0), c5));
}

static ScatterResult material_scatter(const Ray r_in, const HitRecord rec) {
  ScatterResult res;
  vec3 scatter_dir;
  vec3 reflected;
  q16 ri;
  q16 cos_theta;
  q16 sin_theta;
  i32 cannot_refract;
  vec3 direction;

  res.did_scatter = 0;
  res.attenuation = rec.albedo;
  res.scattered = r_in;

  if (rec.mat_kind == MAT_LAMBERTIAN) {
    scatter_dir = vec3_add(rec.normal, random_unit_vector());
    if (vec3_near_zero(scatter_dir) != 0) {
      scatter_dir = rec.normal;
    }
    res.scattered = make_ray(rec.p, scatter_dir);
    res.did_scatter = 1;
    return res;
  }

  if (rec.mat_kind == MAT_METAL) {
    reflected = vec3_reflect(r_in.d, rec.normal);
    reflected = vec3_add(vec3_unit(reflected),
                         vec3_scale(random_unit_vector(), rec.fuzz_or_ref_idx));
    res.scattered = make_ray(rec.p, reflected);
    if (vec3_dot(res.scattered.d, rec.normal) > Q16_ZERO) {
      res.did_scatter = 1;
    }
    return res;
  }

  if (rec.front_face != 0) {
    ri = q_rcp(rec.fuzz_or_ref_idx);
  } else {
    ri = rec.fuzz_or_ref_idx;
  }

  cos_theta = q_min(vec3_dot(vec3_neg(r_in.d), rec.normal), Q16_ONE);
  sin_theta = q_sqrt(q_abs(q_sub(Q16_ONE, q_mul(cos_theta, cos_theta))));
  cannot_refract = (q_mul(ri, sin_theta) > Q16_ONE) ? 1 : 0;

  if (cannot_refract != 0 ||
      schlick_reflectance(cos_theta, ri) > random_q16()) {
    direction = vec3_reflect(r_in.d, rec.normal);
  } else {
    direction = vec3_refract(r_in.d, rec.normal, ri);
  }

  res.scattered = make_ray(rec.p, direction);
  res.did_scatter = 1;
  return res;
}

static Camera camera_init(const q16 vfov_deg, const vec3 lookfrom,
                          const vec3 lookat, const vec3 vup,
                          const q16 defocus_angle_deg, const q16 focus_dist) {
  Camera cam;
  q16 theta;
  q16 h;
  q16 viewport_height;
  q16 actual_aspect;
  q16 viewport_width;
  vec3 w;
  vec3 u;
  vec3 v;
  q16 defocus_rad;

  theta = degrees_to_radians(vfov_deg);
  h = q_tan_small(q_mul(theta, Q16_HALF));
  viewport_height = q_mul(q_mul(Q16_TWO, h), focus_dist);
  actual_aspect = ratio_i32(IMAGE_WIDTH, IMAGE_HEIGHT);
  viewport_width = q_mul(viewport_height, actual_aspect);

  w = vec3_unit_big(vec3_sub(lookfrom, lookat));
  u = vec3_unit(vec3_cross(vup, w));
  v = vec3_cross(w, u);

  cam.center = lookfrom;
  cam.viewport_u = vec3_scale(u, viewport_width);
  cam.viewport_v = vec3_scale(vec3_neg(v), viewport_height);
  cam.viewport_upper_left =
      vec3_sub(vec3_sub(vec3_sub(cam.center, vec3_scale(w, focus_dist)),
                        vec3_scale(cam.viewport_u, Q16_HALF)),
               vec3_scale(cam.viewport_v, Q16_HALF));

  if (defocus_angle_deg <= Q16_ZERO) {
    cam.use_defocus = 0;
    cam.defocus_disk_u = make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
    cam.defocus_disk_v = make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
  } else {
    cam.use_defocus = 1;
    defocus_rad = q_mul(focus_dist, q_tan_small(degrees_to_radians(
                                        q_mul(defocus_angle_deg, Q16_HALF))));
    cam.defocus_disk_u = vec3_scale(u, defocus_rad);
    cam.defocus_disk_v = vec3_scale(v, defocus_rad);
  }

  return cam;
}

static Ray camera_get_ray(const Camera cam, const i32 i, const i32 j) {
  q16 rx;
  q16 ry;
  q16 fx;
  q16 fy;
  vec3 pixel_sample;
  vec3 p_disk;
  vec3 ray_origin;
  Ray r;

  rx = random_q16();
  ry = random_q16();
  fx = q_add(ratio_i32(i, IMAGE_WIDTH),
             q_mul(rx, q_rcp(q16_from_i32(IMAGE_WIDTH))));
  fy = q_add(ratio_i32(j, IMAGE_HEIGHT),
             q_mul(ry, q_rcp(q16_from_i32(IMAGE_HEIGHT))));
  pixel_sample = vec3_add(
      vec3_add(cam.viewport_upper_left, vec3_scale(cam.viewport_u, fx)),
      vec3_scale(cam.viewport_v, fy));

  if (cam.use_defocus == 0) {
    ray_origin = cam.center;
  } else {
    p_disk = random_in_unit_disk();
    ray_origin =
        vec3_add(vec3_add(cam.center, vec3_scale(cam.defocus_disk_u, p_disk.x)),
                 vec3_scale(cam.defocus_disk_v, p_disk.y));
  }
  r.o = ray_origin;
  r.d = vec3_unit_big(vec3_sub(pixel_sample, ray_origin));
  return r;
}

static vec3 ray_color(const Ray initial_ray) {
  Ray cur_ray;
  vec3 throughput;
  i32 depth;
  HitRecord rec;
  ScatterResult sres;
  q16 a;
  vec3 sky_white;
  vec3 sky_blue;
  vec3 sky_col;

  cur_ray = initial_ray;
  throughput = make_vec3(Q16_ONE, Q16_ONE, Q16_ONE);

  for (depth = 0; depth < MAX_DEPTH; depth = depth + 1) {
    rec = world_hit(cur_ray, T_EPS, Q16_INF);
    if (rec.hit != 0) {
      sres = material_scatter(cur_ray, rec);
      if (sres.did_scatter == 0) {
        return make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
      }
      throughput = vec3_mul_elem(throughput, sres.attenuation);
      cur_ray = sres.scattered;
    } else {
      a = q_mul(Q16_HALF, q_add(cur_ray.d.y, Q16_ONE));
      sky_white = make_vec3(Q16_ONE, Q16_ONE, Q16_ONE);
      sky_blue = make_vec3(Q16_CONST(0.5), Q16_CONST(0.7), Q16_ONE);
      sky_col = vec3_add(vec3_scale(sky_white, q_sub(Q16_ONE, a)),
                         vec3_scale(sky_blue, a));
      return vec3_mul_elem(throughput, sky_col);
    }
  }
  return make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
}

static i32 to_byte_gamma(const q16 linear_val) {
  q16 gamma_val;
  const q16 gamma_max = Q16_CONST(0.999);

  if (linear_val <= Q16_ZERO) {
    return 0;
  }
  gamma_val = q_sqrt(linear_val);
  if (gamma_val < Q16_ZERO) {
    gamma_val = Q16_ZERO;
  }
  if (gamma_val > gamma_max) {
    gamma_val = gamma_max;
  }
  return q16_to_i32(q_mul(gamma_val, q16_from_i32(256)));
}

static void write_pixel(const vec3 c) {
  bprint(to_byte_gamma(c.x));
  bprint(to_byte_gamma(c.y));
  bprint(to_byte_gamma(c.z));
}

#ifdef GENERATE_SCENE
static double rand_f01(void) { return (double)random_q16() / 65536.0; }

static double round_2dec(double v) {
  return (v >= 0.0) ? ((int)(v * 100.0 + 0.5)) / 100.0
                    : ((int)(v * 100.0 - 0.5)) / 100.0;
}

/* HSV (h: 0..1, s: 0..1, v: 0..1) から高彩度 RGB への変換 */
static void hsv_to_rgb(double h, double s, double v, double *r, double *g,
                       double *b) {
  double h6 = h * 6.0;
  int sector = (int)h6 % 6;
  double frac = h6 - (int)h6;
  double p = v * (1.0 - s);
  double q = v * (1.0 - s * frac);
  double t = v * (1.0 - s * (1.0 - frac));
  switch (sector) {
  case 0:
    *r = v;
    *g = t;
    *b = p;
    break;
  case 1:
    *r = q;
    *g = v;
    *b = p;
    break;
  case 2:
    *r = p;
    *g = v;
    *b = t;
    break;
  case 3:
    *r = p;
    *g = q;
    *b = v;
    break;
  case 4:
    *r = t;
    *g = p;
    *b = v;
    break;
  default:
    *r = v;
    *g = p;
    *b = q;
    break;
  }
}

int main(int argc, char *argv[]) {
  uint32_t scene_seed =
      (argc > 1) ? (uint32_t)strtoul(argv[1], NULL, 10) : (uint32_t)SEED;
  if (scene_seed == 0)
    scene_seed = 1;
  g_rng_state = scene_seed;

  double sx[64], sy[64], sz[64], sr[64], sr2[64], sar[64], sag[64], sab[64],
      sparam[64];
  int smat[64];

  /* 0..2: 中央の3大球 */
  sx[0] = 0.00;
  sy[0] = 1.00;
  sz[0] = 0.00;
  sr[0] = 1.00;
  sr2[0] = 1.00;
  smat[0] = 2;
  sar[0] = 1.00;
  sag[0] = 1.00;
  sab[0] = 1.00;
  sparam[0] = 1.50;
  sx[1] = -4.00;
  sy[1] = 1.00;
  sz[1] = 0.00;
  sr[1] = 1.00;
  sr2[1] = 1.00;
  smat[1] = 0;
  sar[1] = 0.50;
  sag[1] = 0.90;
  sab[1] = 1.00;
  sparam[1] = 0.00;
  sx[2] = 4.00;
  sy[2] = 1.00;
  sz[2] = 0.00;
  sr[2] = 1.00;
  sr2[2] = 1.00;
  smat[2] = 1;
  sar[2] = 0.80;
  sag[2] = 0.70;
  sab[2] = 0.60;
  sparam[2] = 0.00;

  int count = 3;
  while (count < 64) {
    double cx = round_2dec(-8.50 + 17.50 * rand_f01());
    double cz = round_2dec(-3.80 + 7.60 * rand_f01());

    /* 3大球との衝突回避 (距離^2 >= 1.25) */
    double d0 = (cx - 0.0) * (cx - 0.0) + cz * cz;
    double d1 = (cx + 4.0) * (cx + 4.0) + cz * cz;
    double d2 = (cx - 4.0) * (cx - 4.0) + cz * cz;
    if (d0 < 1.25 || d1 < 1.25 || d2 < 1.25)
      continue;

    /* 小球同士の密集回避 (距離^2 >= 0.56) */
    int overlap = 0;
    for (int j = 3; j < count; j++) {
      double dx = cx - sx[j];
      double dz = cz - sz[j];
      if (dx * dx + dz * dz < 0.56) {
        overlap = 1;
        break;
      }
    }
    if (overlap)
      continue;

    sx[count] = cx;
    sy[count] = 0.20;
    sz[count] = cz;
    sr[count] = 0.20;
    sr2[count] = 0.04;

    double choose_mat = rand_f01();
    double h = rand_f01();
    double r_col, g_col, b_col;

    if (choose_mat < 0.65) {
      /* Lambertian: 彩度 S in [0.82, 0.95], 明度 V in [0.85, 0.96]
       * の高彩度カラー */
      double sat = 0.82 + 0.13 * rand_f01();
      double val = 0.85 + 0.11 * rand_f01();
      hsv_to_rgb(h, sat, val, &r_col, &g_col, &b_col);
      smat[count] = 0;
      sar[count] = round_2dec(r_col);
      sag[count] = round_2dec(g_col);
      sab[count] = round_2dec(b_col);
      sparam[count] = 0.00;
    } else if (choose_mat < 0.88) {
      /* Metal: 彩度 S in [0.45, 0.70], 明度 V in [0.85, 0.96]
       * の鮮やかな色付き金属 */
      double sat = 0.45 + 0.25 * rand_f01();
      double val = 0.85 + 0.11 * rand_f01();
      hsv_to_rgb(h, sat, val, &r_col, &g_col, &b_col);
      smat[count] = 1;
      sar[count] = round_2dec(r_col);
      sag[count] = round_2dec(g_col);
      sab[count] = round_2dec(b_col);
      sparam[count] = round_2dec(0.16 * rand_f01());
    } else {
      /* Dielectric */
      smat[count] = 2;
      sar[count] = 1.00;
      sag[count] = 1.00;
      sab[count] = 1.00;
      sparam[count] = 1.50;
    }
    count++;
  }

  FILE *fc = fopen("scene_const.inc", "w");
  if (fc) {
    fprintf(fc, "#define NUM_SPHERES 64\n");
    fprintf(fc, "static const Sphere SPHERES[NUM_SPHERES] = {\n");
    for (int k = 0; k < 64; k++) {
      fprintf(fc,
              "    SPH_INIT(%.2f, %.2f, %.2f, %.2f, %d, %.2f, %.2f, %.2f, "
              "%.2f)%s\n",
              sx[k], sy[k], sz[k], sr[k], smat[k], sar[k], sag[k], sab[k],
              sparam[k], (k == 63) ? "" : ",");
    }
    fprintf(fc, "};\n");
    fclose(fc);
  }

  FILE *frq = fopen("scene_rq.inc", "w");
  if (frq) {
#define DUMP_Q16(name, arr)                                                    \
  do {                                                                         \
    fprintf(frq, "const %s: [q16; 64] = [\n", name);                           \
    for (int i = 0; i < 64; i++) {                                             \
      if (i % 8 == 0)                                                          \
        fprintf(frq, "    ");                                                  \
      fprintf(frq, "%.2f%s", arr[i], (i == 63) ? "" : ", ");                   \
      if (i % 8 == 7 || i == 63)                                               \
        fprintf(frq, "\n");                                                    \
    }                                                                          \
    fprintf(frq, "];\n\n");                                                    \
  } while (0)

#define DUMP_I32(name, arr)                                                    \
  do {                                                                         \
    fprintf(frq, "const %s: [i32; 64] = [\n", name);                           \
    for (int i = 0; i < 64; i++) {                                             \
      if (i % 8 == 0)                                                          \
        fprintf(frq, "    ");                                                  \
      fprintf(frq, "%d%s", arr[i], (i == 63) ? "" : ", ");                     \
      if (i % 8 == 7 || i == 63)                                               \
        fprintf(frq, "\n");                                                    \
    }                                                                          \
    fprintf(frq, "];\n\n");                                                    \
  } while (0)

    DUMP_Q16("SPHERE_X", sx);
    DUMP_Q16("SPHERE_Y", sy);
    DUMP_Q16("SPHERE_Z", sz);
    DUMP_Q16("SPHERE_R", sr);
    DUMP_Q16("SPHERE_R2", sr2);
    DUMP_I32("SPHERE_MAT", smat);
    DUMP_Q16("SPHERE_AR", sar);
    DUMP_Q16("SPHERE_AG", sag);
    DUMP_Q16("SPHERE_AB", sab);
    DUMP_Q16("SPHERE_PARAM", sparam);
    fclose(frq);
  }

  printf("Generated high-saturation scene (seed=%u) -> 'scene_const.inc' & "
         "'scene_rq.inc'\n",
         scene_seed);
  return 0;
}
#else
int main(void) {
  Camera cam;
  i32 j;
  i32 i;
  i32 s;
  vec3 pixel_acc;
  Ray r;
  vec3 avg_color;

  g_rng_state = (uint32_t)SEED;

  cam = camera_init(
      Q16_CONST(20.0), make_vec3(Q16_CONST(13.0), Q16_TWO, Q16_CONST(3.0)),
      make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO),
      make_vec3(Q16_ZERO, Q16_ONE, Q16_ZERO), Q16_CONST(0.6), Q16_CONST(10.0));

  print_p6_header(IMAGE_WIDTH, IMAGE_HEIGHT);

  for (j = 0; j < IMAGE_HEIGHT; j = j + 1) {
    for (i = 0; i < IMAGE_WIDTH; i = i + 1) {
      pixel_acc = make_vec3(Q16_ZERO, Q16_ZERO, Q16_ZERO);
      for (s = 0; s < SAMPLES_PER_PIXEL; s = s + 1) {
        r = camera_get_ray(cam, i, j);
        pixel_acc = vec3_add(pixel_acc, ray_color(r));
      }
      avg_color = vec3_scale(pixel_acc, q_rcp(q16_from_i32(SAMPLES_PER_PIXEL)));
      write_pixel(avg_color);
    }
  }
  return 0;
}
#endif
