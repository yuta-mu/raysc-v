#ifndef MATERIAL_H
#define MATERIAL_H

#include "rtweekend.h"
#include "hittable.h"
#include "texture.h"

inline fpm_t schlick(fpm_t cosine, fpm_t ref_idx) {
    fpm_t r0 = fpm_div(f_scale - ref_idx, f_scale + ref_idx);
    r0 = fpm_mul(r0, r0);
    const fpm_t x = f_scale - clamp(cosine, 0, f_scale);
    const fpm_t x2 = fpm_mul(x, x);
    const fpm_t x5 = fpm_mul(fpm_mul(x2, x2), x);
    return r0 + fpm_mul(f_scale - r0, x5);
}

class material {
public:
    virtual ~material() {}
    virtual bool scatter(
        const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
    ) const = 0;

    virtual color emitted(fpm_t, fpm_t, const point3&) const {
        return color(0, 0, 0);
    }
};

class lambertian : public material {
public:
    lambertian(const color& a) : albedo(make_shared<solid_color>(a)) {}
    lambertian(shared_ptr<texture> a) : albedo(a) {}

    virtual bool scatter(
        const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
    ) const {
        vec3 scatter_direction = rec.normal + random_unit_vector();
        if (scatter_direction.length_squared() < 8) scatter_direction = rec.normal;
        scattered = ray(rec.p, scatter_direction, r_in.time());
        attenuation = albedo->value(rec.u, rec.v, rec.p);
        return true;
    }
    shared_ptr<texture> albedo;
};

class metal : public material {
public:
    metal(const color& a, fpm_t f) : albedo(a), fuzz(clamp(f, 0, f_scale)) {}

    virtual bool scatter(
        const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
    ) const {
        const vec3 reflected = reflect(unit_vector(r_in.direction()), rec.normal);
        scattered = ray(rec.p, reflected + fuzz * random_in_unit_sphere(), r_in.time());
        attenuation = albedo;
        return dot(scattered.direction(), rec.normal) > 0;
    }
    color albedo;
    fpm_t fuzz;
};

class dielectric : public material {
public:
    dielectric(fpm_t ri) : ref_idx(ri) {}

    virtual bool scatter(
        const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
    ) const {
        attenuation = color(f_scale, f_scale, f_scale);
        const fpm_t ratio = rec.front_face ? fpm_div(f_scale, ref_idx) : ref_idx;
        const vec3 unit_direction = unit_vector(r_in.direction());
        const fpm_t cosine = clamp(dot(-unit_direction, rec.normal), 0, f_scale);
        const fpm_t sine = fpm_sqrt(std::max(0, f_scale - fpm_mul(cosine, cosine)));
        if (fpm_mul(ratio, sine) > f_scale || random_fixed() < schlick(cosine, ratio)) {
            scattered = ray(rec.p, reflect(unit_direction, rec.normal), r_in.time());
        } else {
            scattered = ray(rec.p, refract(unit_direction, rec.normal, ratio), r_in.time());
        }
        return true;
    }
    fpm_t ref_idx;
};

class diffuse_light : public material {
public:
    diffuse_light(shared_ptr<texture> a) : emit(a) {}
    diffuse_light(const color& a) : emit(make_shared<solid_color>(a)) {}

    virtual bool scatter(const ray&, const hit_record&, color&, ray&) const {
        return false;
    }

    virtual color emitted(fpm_t u, fpm_t v, const point3& p) const {
        return emit->value(u, v, p);
    }

public:
    shared_ptr<texture> emit;
};

class isotropic : public material {
public:
    isotropic(shared_ptr<texture> a) : albedo(a) {}
    isotropic(const color& a) : albedo(make_shared<solid_color>(a)) {}

    virtual bool scatter(
        const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
    ) const {
        scattered = ray(rec.p, random_in_unit_sphere(), r_in.time());
        attenuation = albedo->value(rec.u, rec.v, rec.p);
        return true;
    }

public:
    shared_ptr<texture> albedo;
};

#endif
