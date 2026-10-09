#ifndef COLOR_H
#define COLOR_H
#include "vec3.h"
#include <ostream>

using color = vec3;

inline uint32_t color_byte(fpm_t channel) {
  if (channel <= 0) return 0;
  if (channel >= f_scale) return 255;
  return (static_cast<uint32_t>(channel)) >> (f_frac_bits - 8);
}

inline void write_color(std::ostream& out, const color& pixel_color) {
  out << color_byte(pixel_color.x()) << ' '
      << color_byte(pixel_color.y()) << ' '
      << color_byte(pixel_color.z()) << '\n';
}

inline void write_color(std::ostream& out, const color& pixel_color, int samples_per_pixel) {
  const color corrected(
    fpm_sqrt(std::max(0, pixel_color.x() / samples_per_pixel)),
    fpm_sqrt(std::max(0, pixel_color.y() / samples_per_pixel)),
    fpm_sqrt(std::max(0, pixel_color.z() / samples_per_pixel)));
  write_color(out, corrected);
}

#endif
