#ifndef RISCV_QEMU_UART_H
#define RISCV_QEMU_UART_H

#include <stdint.h>

static inline void uart_write_byte(uint8_t value){
    *(volatile uint8_t *)0x10000000 = value;
}

#endif
