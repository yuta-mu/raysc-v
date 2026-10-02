#ifndef COLOR_H
#define COLOR_H
#include "vec3.h"
#include <ostream>

using color = vec3;

inline uint32_t color_byte(fpm_t channel) {
  if (channel <= 0) return 0;
  if (channel >= f_scale) return 255;
  // [0, 1] 内では従来の「255.999を掛けて整数化」と同じ結果。
  // 256で割り切れる境界を1だけ下げてから、小数部の下位8bitを落とす。
  return (static_cast<uint32_t>(channel) - 1u) >> (f_frac_bits - 8);
}

inline void write_color(std::ostream& out, const color& pixel_color) {
  out << color_byte(pixel_color.x()) << ' '
      << color_byte(pixel_color.y()) << ' '
      << color_byte(pixel_color.z()) << '\n';
}

#endif
