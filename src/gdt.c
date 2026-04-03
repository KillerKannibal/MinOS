#include <stdint.h>
#include <string.h>
#include "gdt.h"

struct gdt_entry {
    uint64_t value;
} __attribute__((packed));

struct gdt_ptr {
    uint16_t limit;
    uint64_t base;
} __attribute__((packed));

struct gdt_entry gdt[5];
struct gdt_ptr gp;
struct tss_entry tss;

static void append_tss_entry(uint64_t base, uint32_t limit) {
    uint64_t descriptor_low =
          (uint64_t)(limit & 0xFFFF)
        | ((uint64_t)(base & 0xFFFF) << 16)
        | ((uint64_t)((base >> 16) & 0xFF) << 32)
        | ((uint64_t)0x89 << 40) // present, ring0, type=9 (available 64-bit TSS)
        | ((uint64_t)((limit >> 16) & 0xF) << 48)
        | ((uint64_t)0x0 << 52) // flags: G=0, D/B=0, L=0, AVL=0
        | ((uint64_t)((base >> 24) & 0xFF) << 56);

    uint64_t descriptor_high = (uint64_t)(base >> 32);

    gdt[3].value = descriptor_low;
    gdt[4].value = descriptor_high;
}

void init_gdt() {
    memset(&gdt, 0, sizeof(gdt));
    memset(&tss, 0, sizeof(tss));

    gdt[0].value = 0;
    gdt[1].value = 0x00209A0000000000ULL; // Kernel code
    gdt[2].value = 0x0000920000000000ULL; // Kernel data

    tss.iomap_base = sizeof(tss);
    append_tss_entry((uint64_t)&tss, sizeof(tss) - 1);

    gp.limit = sizeof(gdt) - 1;
    gp.base = (uint64_t)&gdt;

    asm volatile("lgdt %[gp]" : : [gp] "m" (gp));

    asm volatile("mov $0x10, %%ax\n"
                 "mov %%ax, %%ds\n"
                 "mov %%ax, %%es\n"
                 "mov %%ax, %%ss\n"
                 "mov %%ax, %%fs\n"
                 "mov %%ax, %%gs\n"
                 : : : "ax");

    asm volatile("ltr %%ax" : : "a" (0x18));
}
