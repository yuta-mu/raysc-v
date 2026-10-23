#ifndef CORE_COLOR_H
#define CORE_COLOR_H

#include "../fpm.h"
#include "vec3.h"
#include "output.h"

static inline uint32_t color_byte(fpm_t channel){
    if(channel <= 0)return 0;
    if(channel >= f_scale)return 255;
    return ((uint32_t)channel) >> (f_frac_bits - 8);
}

static inline void write_color(vec3 pixel_color){
    output_uint(color_byte(pixel_color.e[0]));
    output_putc(' ');
    output_uint(color_byte(pixel_color.e[1]));
    output_putc(' ');
    output_uint(color_byte(pixel_color.e[2]));
    output_putc('\n');
}

#endif
