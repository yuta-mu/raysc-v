#include <stdio.h> 

// ==========================================
// 1. 固定小数点 (Q16.16) の定義と安全な演算
// ==========================================
typedef int32_t fixed;

#define SHIFT 16
#define ONE (1 << SHIFT) // 65536 (1.0)

#define TO_FIXED(x) ((fixed)((x) * ONE))
#define TO_INT(x)   ((x) >> SHIFT)

// int64_t を使わず、32ビット同士の掛け算でQ16.16を計算する関数
static inline fixed fixed_mul(fixed a, fixed b) {
    int32_t ah = a >> 16, al = a & 0xFFFF;
    int32_t bh = b >> 16, bl = b & 0xFFFF;
    return (ah * bh << 16) + (ah * bl) + (al * bh) + ((al * bl) >> 16);
}

static inline fixed fixed_div(fixed a, fixed b) {
    if (b == 0) return 0;
    return (fixed)(((long long)a << SHIFT) / b);
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
// 4. メイン関数（動作テスト用）
// ==========================================
int main(void) {
    // 固定小数点のテスト演算 (1.5 * 2.0 = 3.0 の確認)
    fixed a = TO_FIXED(3) / 2; // 1.5
    fixed b = TO_FIXED(2);     // 2.0
    fixed res = fixed_mul(a, b);

    printf("--- Q16.16 Fixed Point Test ---\n");
    printf("1.5 * 2.0 = %d (Integer part: %d)\n", res, TO_INT(res));
    
    // ベクトル演算のテスト
    Vec3 v1 = vec3_create(TO_FIXED(1), TO_FIXED(2), TO_FIXED(3));
    Vec3 v2 = vec3_create(TO_FIXED(4), TO_FIXED(5), TO_FIXED(6));
    Vec3 v3 = vec3_add(v1, v2);

    printf("Vec3 Add Test: x=%d, y=%d, z=%d\n", TO_INT(v3.x), TO_INT(v3.y), TO_INT(v3.z));
    printf("--- Setup OK! ---\n");

    return 0;
}