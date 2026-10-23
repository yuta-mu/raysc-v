#ifndef CORE_COLOR_H
#define CORE_COLOR_H

#include "../fpm.h"
#include "vec3.h"
#include <stdio.h>
#include <inttypes.h>

static inline uint32_t color_byte(fpm_t channel){
    if(channel <= 0)return 0;
    if(channel >= f_scale)return 255;
    return ((uint32_t)channel) >> (f_frac_bits - 8);
}

static inline void write_color(FILE* out, vec3 pixel_color){
    fprintf(out,"%" PRIu32 " %" PRIu32 " %" PRIu32 "\n",
        color_byte(pixel_color.e[0]),
        color_byte(pixel_color.e[1]),
        color_byte(pixel_color.e[2]));
}

#endif