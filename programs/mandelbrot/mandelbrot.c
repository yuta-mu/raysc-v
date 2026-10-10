#define UART_TX ((volatile unsigned char *)0x10000000)

void uart_putc(char c) { *UART_TX = c; }

void uart_puts(const char *s) {
  while (*s) {
    uart_putc(*s++);
  }
}

int __mulsi3(int a, int b) {
    int res = 0;
    unsigned int ua = (unsigned int)a;
    unsigned int ub = (unsigned int)b;
    while (ub != 0) {
        if (ub & 1) {
            res += ua;
        }
        ua <<= 1;
        ub >>= 1;
    }
    return res;
}

// 32-bit 符号なし除算ルーチン
unsigned int __udivsi3(unsigned int n, unsigned int d) {
    if (d == 0) return 0; // ゼロ除算保護
    unsigned int q = 0, r = 0;
    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1);
        if (r >= d) {
            r -= d;
            q |= (1U << i);
        }
    }
    return q;
}

// 32-bit 符号付き除算ルーチン
int __divsi3(int n, int d) {
    int sign = 1;
    unsigned int un = n;
    unsigned int ud = d;
    if (n < 0) { sign = -sign; un = -n; }
    if (d < 0) { sign = -sign; ud = -d; }
    unsigned int q = __udivsi3(un, ud);
    return (sign < 0) ? -(int)q : (int)q;
}

// 固定小数点設定 (Q20.12)
#define SHIFT 12
#define ONE (1 << SHIFT) // 4096
#define FOUR (4 * ONE)

#define WIDTH 90
#define HEIGHT 30
#define MAX_ITER 64

void render_mandelbrot(void) {
  int x_min = -21 * ONE / 10;
  int x_max = 9 * ONE / 10;
  int y_min = -12 * ONE / 10;
  int y_max = 12 * ONE / 10;

  int dx = (x_max - x_min) / WIDTH;
  int dy = (y_max - y_min) / HEIGHT;

  const char charset[] = " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$";
  int num_chars = sizeof(charset) - 2;

  for (int row = 0; row < HEIGHT; row++) {
    int ci = y_min + row * dy;
    for (int col = 0; col < WIDTH; col++) {
      int cr = x_min + col * dx;

      int zr = 0;
      int zi = 0;
      int iter = 0;

      while (iter < MAX_ITER) {
        int zr2 = (zr * zr) >> SHIFT;
        int zi2 = (zi * zi) >> SHIFT;

        if (zr2 + zi2 > FOUR) {
          break;
        }

        int zr_zi = (zr * zi) >> SHIFT;
        zi = (zr_zi << 1) + ci;

        zr = zr2 - zi2 + cr;

        iter++;
      }

      if (iter == MAX_ITER) {
        uart_putc('#');
      } else {
        uart_putc(charset[(iter * num_chars) / MAX_ITER]);
      }
    }
    uart_putc('\n');
  }
}

int main(void) {
  uart_puts("\n--- RV32I Mandelbrot Demo ---\n\n");
  render_mandelbrot();
  uart_puts("\n--- Done! ---\n");
  return 0;
}
