#ifndef CORE_OUTPUT_H
#define CORE_OUTPUT_H

#include <stdint.h>

void output_putc(char c);

static inline void output_uint(uint32_t value){
    char digits[10];
    int count = 0;
    do {
        digits[count++] = (char)('0' + value % 10);
        value /= 10;
    } while (value != 0);
    while (count > 0){
        output_putc(digits[--count]);
    }
}

static inline void output_ppm_header(uint32_t width, uint32_t height){
    output_putc('P');
    output_putc('3');
    output_putc('\n');
    output_uint(width);
    output_putc(' ');
    output_uint(height);
    output_putc('\n');
    output_uint(255);
    output_putc('\n');
}

#endif
