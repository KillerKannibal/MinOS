#include <stdint.h>

static inline void outb(uint16_t port, uint8_t val) {
    asm volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline int inb(uint16_t port) {
    uint8_t ret;
    asm volatile("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

static void write_char(char c) {
    while (!(inb(0x3F9) & 0x20));
    outb(0x3F8, c);
}

void kernel_main(void *mbinfo) {
    // CRITICAL: Directly output to serial without any setup
    // Port 0xE9 is QEMU's debug console (also works as 0x3F8 COM1)
    asm volatile("mov $0x58, %%al; mov $0xE9, %%dx; out %%al, %%dx" : : : "al", "dx");  // 'X'
    asm volatile("mov $0x0A, %%al; mov $0xE9, %%dx; out %%al, %%dx" : : : "al", "dx");  // '\n'
    
    // Halt
    while (1) {
        asm volatile("hlt");
    }
}
