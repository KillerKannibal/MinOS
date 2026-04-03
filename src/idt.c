#include <stdint.h>
#include <string.h>
#include "idt.h"
#include "io.h"

struct idt_entry idt[256];
struct idt_ptr idtp;

extern void idt_load(uint64_t);
extern void keyboard_asm_handler();
extern void irq_common_stub();
extern void mouse_asm_handler();

static void idt_set_gate(uint8_t num, uint64_t base, uint16_t sel, uint8_t flags, uint8_t ist) {
    idt[num].offset_low = base & 0xFFFF;
    idt[num].selector = sel;
    idt[num].ist = ist & 0x7;
    idt[num].type_attr = flags;
    idt[num].offset_mid = (base >> 16) & 0xFFFF;
    idt[num].offset_high = (base >> 32) & 0xFFFFFFFF;
    idt[num].zero = 0;
}

void init_idt() {
    memset(&idt, 0, sizeof(idt));

    idtp.limit = sizeof(idt) - 1;
    idtp.base = (uint64_t)&idt;

    for (int i = 0; i < 256; i++) {
        idt_set_gate(i, (uint64_t)irq_common_stub, 0x08, 0x8E, 0);
    }

    outb(0x20, 0x11); outb(0xA0, 0x11);
    outb(0x21, 0x20); outb(0xA1, 0x28);
    outb(0x21, 0x04); outb(0xA1, 0x02);
    outb(0x21, 0x01); outb(0xA1, 0x01);
    outb(0x21, 0xF9);
    outb(0xA1, 0xEF);

    idt_set_gate(0x21, (uint64_t)keyboard_asm_handler, 0x08, 0x8E, 0);
    idt_set_gate(44,  (uint64_t)mouse_asm_handler,    0x08, 0x8E, 0);

    idt_load((uint64_t)&idtp);
}
