#include "../core/output.h"
#include "uart.h"

void output_putc(char c){
    uart_write_byte((unsigned char)c);
}
