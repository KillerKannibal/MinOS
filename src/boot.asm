; Updated Diagnostic boot stub for ExileOS (64-bit transition)
MBALIGN  equ 1<<0
MEMINFO  equ 1<<1
VIDEO    equ 1<<2
MAGIC    equ 0x1BADB002
FLAGS    equ MBALIGN | MEMINFO | VIDEO
CHECKSUM equ -(MAGIC + FLAGS)

section .multiboot
align 4
    dd MAGIC
    dd FLAGS
    dd CHECKSUM
    ; Video mode fields (required when VIDEO bit is set)
    dd 0    ; mode_type (0 = linear graphics)
    dd 800  ; width
    dd 600  ; height
    dd 32   ; depth

section .bss
align 16
    stack: resb 4096

align 4096
    pml4: resq 512
    pdpt: resq 512
    pdt:  resq 2048 ; Expanded to 4 tables to cover 4GB (512 * 2MB * 4)

section .text
bits 32
global _start
extern kernel_main
extern sbss
extern ebss

_start:
    ; Initialize Serial Port (COM1)
    mov dx, 0x3F8 + 1
    mov al, 0x00
    out dx, al
    mov dx, 0x3F8 + 3
    mov al, 0x80
    out dx, al
    mov dx, 0x3F8 + 0
    mov al, 0x03
    out dx, al
    mov dx, 0x3F8 + 1
    mov al, 0x00
    out dx, al
    mov dx, 0x3F8 + 3
    mov al, 0x03
    out dx, al

    cli
    cld

    ; Clear BSS
    mov edi, sbss
    mov ecx, ebss
    sub ecx, edi
    xor eax, eax
    rep stosb

    ; Stack setup
    mov esp, stack + 4096

    ; Paging Setup (Identity mapping 0MB to 4096MB via 2MB Huge Pages)
    ; PML4[0] -> PDPT[0]
    mov eax, pml4
    xor edx, edx ; Ensure high bits are 0
    mov [eax], dword pdpt + 0x03 ; PRESENT | WRITABLE
    mov [eax + 4], dword 0

    ; PDPT[0,1,2,3] -> 4 separate Page Directory Tables
    ; This covers 4GB of physical address space
    mov eax, pdpt
    mov [eax], dword pdt + 0x03      ; PDPT entry 0 (0-1GB)
    mov [eax + 4], dword 0
    
    mov [eax + 8], dword pdt + 4096 + 0x03  ; PDPT entry 1 (1-2GB)
    mov [eax + 12], dword 0
    
    mov [eax + 16], dword pdt + 8192 + 0x03 ; PDPT entry 2 (2-3GB)
    mov [eax + 20], dword 0
    
    mov [eax + 24], dword pdt + 12288 + 0x03 ; PDPT entry 3 (3-4GB)
    mov [eax + 28], dword 0

    ; Fill the PDTs with 2048 entries (4 * 512)
    mov edi, pdt
    mov eax, 0x00000183  ; PRESENT | WRITABLE | HUGE_PAGE
    mov ecx, 2048
.loop_paging:
    mov [edi], eax
    mov [edi + 4], dword 0
    add edi, 8
    add eax, 0x200000    ; Next 2MB page
    loop .loop_paging

    ; Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; Load PML4
    mov eax, pml4
    mov cr3, eax

    ; Enable Long Mode in EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; Enable Paging
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    lgdt [gdt_ptr]

    ; Long jump to 64-bit code segment
    jmp 0x08:.lm

bits 64
.lm:
    ; Set up 64-bit data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    mov rsp, stack + 4096
    
    ; Pass Multiboot pointer (rbx) to kernel_main (rdi)
    mov rdi, rbx
    call kernel_main

    ; If kernel returns, halt
    cli
.h:
    hlt
    jmp .h

section .data
align 8
gdt:
    dq 0                         ; Null descriptor
    dq 0x00209A0000000000        ; 64-bit Code (Kernel)
    dq 0x0000920000000000        ; 64-bit Data (Kernel)
gdt_len equ $ - gdt

gdt_ptr:
    dw gdt_len - 1
    dd gdt ; 32-bit base for lgdt in 32-bit mode

global idt_load
idt_load:
    lidt [rdi]
    ret
