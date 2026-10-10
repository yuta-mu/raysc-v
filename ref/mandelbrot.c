#include "qmath.h"
#include <stdint.h>

typedef uint32_t q16_t;

#define Q16_FROM_INT(x) ((uint32_t)((int32_t)(x) << 16))
#define Q16_FROM_FLOAT(x) ((uint32_t)(int32_t)((x) * 65536.0f))

#define WIDTH 90
#define HEIGHT 30
#define MAX_ITER 64
#define NUM_CHARS 60

#define X_MIN ((uint32_t)(int32_t)-137626) /* -2.1 */
#define X_MAX ((uint32_t)58982)            /*  0.9 */
#define Y_MIN ((uint32_t)(int32_t)-78643)  /* -1.2 */
#define Y_MAX ((uint32_t)78643)            /*  1.2 */
#define FOUR (Q16_FROM_INT(4))

static const char CHARSET[NUM_CHARS] = {
    ' ', '.', '\'', '`', '^', '"', ',', ':', ';', 'I', 'l', '!', 'i', '>', '<',
    '~', '+', '_',  '-', '?', ']', '[', '}', '{', '1', ')', '(', '|', '/', 't',
    'f', 'j', 'r',  'x', 'n', 'u', 'v', 'c', 'z', 'X', 'Y', 'U', 'J', 'C', 'L',
    'Q', '0', 'O',  'Z', 'm', 'w', 'q', 'p', 'd', 'b', 'k', 'h', 'a', 'o', '*'};

#define UART_TX ((volatile unsigned char *)0x10000000)
static inline void out_char(char c) { *UART_TX = (unsigned char)c; }
static inline void out_str(const char *s) {
  while (*s)
    out_char(*s++);
}

void render_mandelbrot(void) {
  q16_t dx = q16_mul(X_MAX - X_MIN, q16_rcp(Q16_FROM_INT(WIDTH)));
  q16_t dy = q16_mul(Y_MAX - Y_MIN, q16_rcp(Q16_FROM_INT(HEIGHT)));

  for (int row = 0; row < HEIGHT; row++) {
    q16_t ci = Y_MIN + q16_mul(Q16_FROM_INT(row), dy);

    for (int col = 0; col < WIDTH; col++) {
      q16_t cr = X_MIN + q16_mul(Q16_FROM_INT(col), dx);

      q16_t zr = 0;
      q16_t zi = 0;
      int iter = 0;

      while (iter < MAX_ITER) {
        q16_t zr2 = q16_mul(zr, zr);
        q16_t zi2 = q16_mul(zi, zi);

        if ((int32_t)(zr2 + zi2) > (int32_t)FOUR) {
          break;
        }

        q16_t zr_zi = q16_mul(zr, zi);
        zi = q16_mul(zr_zi, Q16_FROM_INT(2)) + ci;
        zr = zr2 - zi2 + cr;

        iter++;
      }

      if (iter == MAX_ITER) {
        out_char('#');
      } else {
        int char_idx = (iter * NUM_CHARS) / MAX_ITER;
        out_char(CHARSET[char_idx]);
      }
    }
    out_char('\n');
  }
}

int main(void) {
  out_str("\n--- RaySC-V Mandelbrot Demo ---\n\n");
  render_mandelbrot();
  out_str("\n--- Done! ---\n");
  return 0;
}
