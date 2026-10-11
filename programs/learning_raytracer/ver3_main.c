#include <stdlib.h>
#include <stdio.h>

// ==========================================
// 1. 固定小数点 (Q16.16) の定義と安全な演算
// ==========================================
typedef int32_t fixed;

#define SHIFT 16
#define ONE (1 << SHIFT) // 65536 (1.0)

#define TO_FIXED(x) ((fixed)((x) * ONE))
#define TO_INT(x)   ((x) >> SHIFT)

// 正しい fixed_mul（int64_t を使ってオーバーフローを防ぐ）
static inline fixed fixed_mul(fixed a, fixed b) {
    return (fixed)(((int64_t)a * b) >> SHIFT);
}

// 正しい fixed_div
static inline fixed fixed_div(fixed a, fixed b) {
    if (b == 0) return 0;
    return (fixed)(((int64_t)a << SHIFT) / b);
}

// 整数用の平方根（バビロニア法）
static inline fixed fixed_sqrt(fixed x) {
    if (x <= 0) return 0;
    fixed guess = x;
    fixed prev = 0;
    for (int i = 0; i < 10; i++) {
        prev = guess;
        guess = (guess + fixed_div(x, guess)) >> 1;
        if (guess == prev) break;
    }
    return guess;
}

// ==========================================
// 2. ベクトル構造体 (Vec3) と演算
// ==========================================
typedef struct {
    fixed x, y, z;
} Vec3;

static inline Vec3 vec3_create(fixed x, fixed y, fixed z) {
    return (Vec3){x, y, z};
}

static inline Vec3 vec3_add(Vec3 u, Vec3 v) {
    return (Vec3){u.x + v.x, u.y + v.y, u.z + v.z};
}

static inline Vec3 vec3_sub(Vec3 u, Vec3 v) {
    return (Vec3){u.x - v.x, u.y - v.y, u.z - v.z};
}

static inline Vec3 vec3_mul_scalar(Vec3 v, fixed t) {
    return (Vec3){fixed_mul(v.x, t), fixed_mul(v.y, t), fixed_mul(v.z, t)};
}

static inline fixed vec3_dot(Vec3 u, Vec3 v) {
    return fixed_mul(u.x, v.x) + fixed_mul(u.y, v.y) + fixed_mul(u.z, v.z);
}

static inline fixed vec3_length_squared(Vec3 v) {
    return vec3_dot(v, v);
}

// ==========================================
// 3. レイ構造体 (Ray)
// ==========================================
typedef struct {
    Vec3 origin;
    Vec3 direction;
} Ray;

static inline Vec3 ray_at(Ray r, fixed t) {
    return vec3_add(r.origin, vec3_mul_scalar(r.direction, t));
}

// ==========================================
// 4. 球との交差判定 (Hit Sphere)
// ==========================================
fixed hit_sphere(Vec3 center, fixed radius, Ray r) {
    Vec3 oc = vec3_sub(r.origin, center);
    fixed a = vec3_length_squared(r.direction);
    fixed half_b = vec3_dot(oc, r.direction);
    fixed c = vec3_length_squared(oc) - fixed_mul(radius, radius);
    
    fixed discriminant = fixed_mul(half_b, half_b) - fixed_mul(a, c);
    if (discriminant < 0) {
        return -1;
    } else {
        return fixed_div(-half_b - fixed_sqrt(discriminant), a);
    }
}

// ==========================================
// 5. メイン処理（PPM画像出力）
// ==========================================
int main(void) {
    int image_width = 200;
    int image_height = 100;

    printf("P3\n%d %d\n255\n", image_width, image_height);

    fixed aspect_ratio = fixed_div(TO_FIXED(image_width), TO_FIXED(image_height));
    fixed viewport_height = TO_FIXED(2);
    fixed viewport_width = fixed_mul(aspect_ratio, viewport_height);
    fixed focal_length = ONE;

    Vec3 camera_center = vec3_create(0, 0, 0);
    Vec3 viewport_u = vec3_create(viewport_width, 0, 0);
    Vec3 viewport_v = vec3_create(0, -viewport_height, 0);

    Vec3 pixel_delta_u = vec3_mul_scalar(viewport_u, fixed_div(ONE, TO_FIXED(image_width)));
    Vec3 pixel_delta_v = vec3_mul_scalar(viewport_v, fixed_div(ONE, TO_FIXED(image_height)));

    Vec3 viewport_upper_left = vec3_sub(
        vec3_sub(vec3_sub(camera_center, vec3_create(0, 0, focal_length)), 
        vec3_mul_scalar(viewport_u, TO_FIXED(1)/2)), 
        vec3_mul_scalar(viewport_v, TO_FIXED(1)/2)
    );

    // 球の定義（中心: (0, 0, -1.5), 半径: 0.5）
    Vec3 sphere_center = vec3_create(0, 0, -TO_FIXED(3)/2);
    fixed sphere_radius = TO_FIXED(1)/2;

    for (int j = 0; j < image_height; j++) {
        fprintf(stderr, "\rScanlines remaining: %d ", image_height - j);
        fflush(stderr);
        for (int i = 0; i < image_width; i++) {
            Vec3 pixel_center = vec3_add(
                viewport_upper_left, 
                vec3_add(vec3_mul_scalar(pixel_delta_u, TO_FIXED(i)), 
                         vec3_mul_scalar(pixel_delta_v, TO_FIXED(j)))
            );
            Vec3 ray_direction = vec3_sub(pixel_center, camera_center);
            Ray r = {camera_center, ray_direction};

            fixed t = hit_sphere(sphere_center, sphere_radius, r);

            int ir = 0, ig = 0, ib = 0;

            if (t > 0) {
                // 当たったら赤色
                ir = 255;
                ig = 100;
                ib = 100;
            } else {
                // 背景（青空グラデーション）
                ir = 150;
                ig = 180;
                ib = 255;
            }

            printf("%d %d %d\n", ir, ig, ib);
        }
    }

    fprintf(stderr, "\nDone. Render complete!\n");
    return 0;
}