#include <stdint.h>
#include "ref/qmath.h"

// QEMU virt マシンの UART ベースアドレス
#define UART_BASE 0x10000000

// アセンブリで定義された関数の外部宣言
extern uint32_t __q16_rsqrt(uint32_t x_raw);

// ==========================================
// UART 入出力関数の自作 (stdio.h 代替)
// ==========================================
static inline void uart_putchar(char c) {
    volatile uint32_t *uart_tx = (volatile uint32_t *)UART_BASE;
    *uart_tx = (uint32_t)c;
}

static void uart_puts(const char *s) {
    while (*s != '\0') {
        uart_putchar(*s);
        s++;
    }
}

// 16進数出力ヘルパー (例: 0x12345678)
static void uart_put_hex(uint32_t val) {
    char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        int nibble = (val >> (i * 4)) & 0xF;
        uart_putchar(hex_chars[nibble]);
    }
}

int main(void) {
    uart_puts("=== q16_rsqrt Boundary & Random Test on QEMU ===\n");

    // ==========================================
    // 1. 境界値テスト (Boundary Value Analysis)
    // ==========================================
    uart_puts("[1/2] Running Boundary Value Tests...\n");
    uint32_t bounds[] = {
        0x00000000U, // 0 (特異点)
        0x00000001U, // 1 (正の最小値)
        0x00000002U, // 2
        0x00000003U, // 3
        0x01000000U, // 2^24 (アルゴリズムの初期bit値)
        0x7FFFFFFFU,
        0x80000000U, // 負の境界 (符号切替点)
        0x80000001U, // 負の領域
        0xFFFFFFFEU, // 負の最大付近 (-2)
        0xFFFFFFFFU  // 負の最大 (-1)
    };
    
    // ※ 上記の配列をクリーンに定義し直したもの
    uint32_t boundaries[] = {
        0x00000000U,
        0x00000001U,
        0x00000002U,
        0x00000003U,
        0x01000000U,
        0x7FFFFFFFU,
        0x80000000U,
        0x80000001U,
        0xFFFFFFFEU,
        0xFFFFFFFFU
    };

    int b_fails = 0;
    int b_count = sizeof(boundaries) / sizeof(boundaries[0]);

    for (int i = 0; i < b_count; i++) {
        uint32_t x_raw = boundaries[i];
        uint32_t asm_res = __q16_rsqrt(x_raw);
        uint32_t c_res   = q16_rsqrt(x_raw);

        if (asm_res != c_res) {
            uart_puts("  [FAIL] x=");
            uart_put_hex(x_raw);
            uart_puts(" asm=");
            uart_put_hex(asm_res);
            uart_puts(" c=");
            uart_put_hex(c_res);
            uart_puts("\n");
            b_fails++;
        }
    }

    if (b_fails == 0) {
        uart_puts("  -> Boundary Tests: PASS\n");
    } else {
        uart_puts("  -> Boundary Tests: FAIL\n");
        return 1;
    }

    // ==========================================
    // 2. 乱数テスト (Xorshift32 によるサンプリング)
    // ==========================================
    uart_puts("[2/2] Running Random Tests (1,000,000 iterations)...\n");
    uint32_t state = 2463534242U;
    uint32_t r_fails = 0;
    uint32_t num_iters = 1000000U; // QEMU上で数秒〜十数秒で終わる適切な回数

    for (uint32_t i = 0; i < num_iters; i++) {
        // Xorshift 乱数生成
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        uint32_t x_raw = state;

        uint32_t asm_res = __q16_rsqrt(x_raw);
        uint32_t c_res   = q16_rsqrt(x_raw);

        if (asm_res != c_res) {
            uart_puts("  [FAIL] rand x=");
            uart_put_hex(x_raw);
            uart_puts(" asm=");
            uart_put_hex(asm_res);
            uart_puts(" c=");
            uart_put_hex(c_res);
            uart_puts("\n");
            r_fails++;
            if (r_fails >= 10) {
                uart_puts("Too many errors, aborting.\n");
                return 1;
            }
        }
    }

    if (r_fails == 0) {
        uart_puts("  -> Random Tests: PASS\n");
        uart_puts("SUCCESS: All tests passed successfully!\n");
    } else {
        uart_puts("  -> Random Tests: FAIL\n");
        return 1;
    }

    return 0;
}

