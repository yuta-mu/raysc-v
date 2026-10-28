#ifndef CORE_COLOR_H
#define CORE_COLOR_H
#ifndef RENDER_GAMMA2
#define RENDER_GAMMA2 0
#endif

#include "../fpm.h"
#include "vec3.h"
#include "output.h"

static inline uint32_t color_byte(fpm_t channel){
    if(channel <= 0)return 0;
    if(channel >= f_scale)return 255;
    return ((uint32_t)channel) >> (f_frac_bits - 8);
}


static inline uint32_t color_byte_gamma2(fpm_t channel){
    if (channel <= 0)return 0;
    fpm_t const result = fpm_sqrt(channel);
    return color_byte(result);
}

static inline uint32_t color_byte_output(fpm_t channel){
    if (!RENDER_GAMMA2)return color_byte(channel);
    else return color_byte_gamma2(channel);
}

static inline void write_color(vec3 pixel_color){
    output_uint(color_byte_output(pixel_color.e[0]));
    output_putc(' ');
    output_uint(color_byte_output(pixel_color.e[1]));
    output_putc(' ');
    output_uint(color_byte_output(pixel_color.e[2]));
    output_putc('\n');
}


#endif
