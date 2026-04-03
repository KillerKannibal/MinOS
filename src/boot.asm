; Diagnostic boot stub - extremely minimal
MBALIGN  equ 1<<0
MEMINFO  equ 1<<1
MAGIC    equ 0x1BADB002
FLAGS    equ MBALIGN | MEMINFO
CHECKSUM equ -(MAGIC + FLAGS)

section .multiboot
align 4
    dd MAGIC
    dd FLAGS
    dd CHECKSUM

section .bss
align 16
    stack: resb 4096

align 4096
    pml4: resq 512
    pdpt: resq 512
    pdt: resq 512

section .text
bits 32
global _start
extern kernel_main
extern sbss
extern ebss

_start:
    ; Output debug char to QEMU console (port 0xE9)
    mov al, '1'
    out 0xE9, al

    ; Minimal setup
    cli
    cld

    ; Output debug char
    mov al, '2'
    out 0xE9, al

    ; Clear BSS (basic C needs this)
    mov edi, sbss
    mov ecx, ebss
    sub ecx, edi
    xor eax, eax
    rep stosb

    ; Stack setup
    mov esp, stack + 4096

    ; Minimal paging: PML4[0] -> PDPT[0] -> PDT (identity map 2M huge pages)
    mov eax, pdpt
    or eax, 0x03
    mov [pml4], eax

    mov eax, pdt
    or eax, 0x03
    mov [pdpt], eax

    ; Fill PDT with 512 2MB pages
    mov edi, pdt
    mov eax, 0x00000183  ; PRESENT | WRITABLE | HUGE_PAGE
    mov ecx, 512
.loop:
    mov [edi], eax
    add edi, 8
    add eax, 0x200000
    loop .loop

    ; CR4.PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; CR3 = PML4
    lea eax, [pml4]
    mov cr3, eax

    ; EFER.LME
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; CR0.PG
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Load GDT and jump to 64-bit
    mov al, '3'
    out 0xE9, al

    lgdt [gdt_ptr]

    mov al, '4'
    out 0xE9, al

    jmp 0x08:.lm

bits 64
.lm:
    mov rax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov rsp, stack + 4096
    mov rdi, rbx
    call kernel_main

    cli
.h:
    hlt
    jmp .h

section .data
align 8
gdt:
    dq 0
    dq 0x00209A0000000000
    dq 0x0000920000000000
gdt_len equ $ - gdt

gdt_ptr:
    dw gdt_len - 1
    dq gdt

global idt_load
idt_load:
    lidt [rdi]
    ret
