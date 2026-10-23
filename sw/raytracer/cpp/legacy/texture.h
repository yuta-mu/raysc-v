#ifndef TEXTURE_H
#define TEXTURE_H

#include "rtweekend.h"
#include "vec3.h"
#include "perlin.h"
#include "rtw_stb_image.h"
#include <iostream>

class texture {
public:
  virtual ~texture() {}
  virtual color value(fpm_t u, fpm_t v, const point3& p) const = 0;
};

class solid_color : public texture {
public:
  solid_color() {}
  solid_color(color c) : color_value(c) {}
  solid_color(fpm_t red, fpm_t green, fpm_t blue)
    : solid_color(color(red,green,blue)) {}

  virtual color value(fpm_t, fpm_t, const point3&) const {
    return color_value;
  }

private:
  color color_value;
};

class checker_texture : public texture {
public:
  checker_texture() {}
  checker_texture(shared_ptr<texture> t0, shared_ptr<texture> t1) : even(t0), odd(t1) {}

  virtual color value(fpm_t u, fpm_t v, const point3& p) const {
    const auto x = fpm_sin(10 * (p.x() % (2 * pi)));
    const auto y = fpm_sin(10 * (p.y() % (2 * pi)));
    const auto z = fpm_sin(10 * (p.z() % (2 * pi)));
    if (x != 0 && y != 0 && z != 0 && ((x < 0) ^ (y < 0) ^ (z < 0)))
      return odd->value(u, v, p);
    return even->value(u, v, p);
  }

public:
  shared_ptr<texture> even;
  shared_ptr<texture> odd;
};

class noise_texture : public texture {
public:
  noise_texture() : scale(f_scale) {}
  noise_texture(fpm_t sc) : scale(sc) {}

  virtual color value(fpm_t, fpm_t, const point3& p) const {
    return color(f_scale, f_scale, f_scale) *
           ((f_scale + fpm_sin(fpm_mul(scale, p.z()) + 10 * noise.turb(p))) / 2);
  }

public:
  perlin noise;
  fpm_t scale;
};

class image_texture : public texture {
public:
  const static int bytes_per_pixel = 3;

  image_texture()
    : data(nullptr), width(0), height(0), bytes_per_scanline(0) {}

  image_texture(const char* filename)
    : data(nullptr), width(0), height(0), bytes_per_scanline(0) {
    auto components_per_pixel = bytes_per_pixel;
    data = stbi_load(filename, &width, &height, &components_per_pixel, components_per_pixel);
    if (!data) {
      std::cerr << "ERROR: Could not load texture image file '" << filename << "'.\n";
      width = height = 0;
    }
    bytes_per_scanline = bytes_per_pixel * width;
  }

  image_texture(const image_texture&) = delete;
  image_texture& operator=(const image_texture&) = delete;

  ~image_texture() {
    stbi_image_free(data);
  }

  bool loaded() const { return data != nullptr; }

  virtual color value(fpm_t u, fpm_t v, const point3&) const {
    if (data == nullptr)
      return color(0, f_scale, f_scale);

    u = clamp(u, 0, f_scale);
    v = f_scale - clamp(v, 0, f_scale);
    auto i = pixel_index(u, width);
    auto j = pixel_index(v, height);
    auto pixel = data + static_cast<size_t>(j) * bytes_per_scanline + i * bytes_per_pixel;
    return color(pixel[0] * f_scale / 255, pixel[1] * f_scale / 255, pixel[2] * f_scale / 255);
  }

private:
  static int pixel_index(fpm_t coordinate, int size) {
    const uint32_t count = static_cast<uint32_t>(size);
    const uint32_t value = static_cast<uint32_t>(coordinate);
    const uint32_t index = value * (count >> f_frac_bits)
                         + ((value * (count & 0xffffu)) >> f_frac_bits);
    return std::min(static_cast<int>(index), size - 1);
  }

  unsigned char* data;
  int width, height;
  int bytes_per_scanline;
};

#endif
