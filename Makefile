# Toolchain - WSL2 Native
CC = gcc
AS = nasm

# ExileOS Build Flags
# -m64: Force 64-bit for the Exile architecture
# -fno-stack-protector: Stop the compiler from asking for libs Thor doesn't have yet
CFLAGS = -m64 -ffreestanding -fno-stack-protector -fno-pie -fno-leading-underscore -mno-sse -mno-mmx -mno-sse2 -O2 -Wall -Wextra -Isrc
ASFLAGS = -f elf64

# Project structure
SRCDIR = src
BUILDDIR = build
OBJS = $(BUILDDIR)/boot.o $(BUILDDIR)/main.o $(BUILDDIR)/globals.o $(BUILDDIR)/wm.o $(BUILDDIR)/shell.o \
       $(BUILDDIR)/editor.o $(BUILDDIR)/calc.o $(BUILDDIR)/fileman.o $(BUILDDIR)/game.o $(BUILDDIR)/debug.o \
       $(BUILDDIR)/input.o $(BUILDDIR)/rtc.o $(BUILDDIR)/utils.o \
       $(BUILDDIR)/gdt.o $(BUILDDIR)/idt.o $(BUILDDIR)/interrupts.o $(BUILDDIR)/fs.o \
       $(BUILDDIR)/string.o $(BUILDDIR)/gui.o $(BUILDDIR)/pci.o $(BUILDDIR)/net.o $(BUILDDIR)/rtl8139.o $(BUILDDIR)/browser.o

KERNEL = $(BUILDDIR)/myos.bin
INITRD = $(BUILDDIR)/initrd.tar
ISO = ExileOS.iso

.PHONY: all run test clean

all: $(ISO)

# The "Thor" Strike - Linking the Kernel
$(KERNEL): $(OBJS) $(SRCDIR)/linker.ld
	$(CC) -T $(SRCDIR)/linker.ld -o $(KERNEL).64 $(OBJS) -m64 -nostdlib -ffreestanding -fno-pie -no-pie -Wl,--build-id=none -lgcc
	objcopy -I elf64-x86-64 -O elf32-i386 $(KERNEL).64 $(KERNEL)

# Compiling C files
$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Assembling Assembly files
$(BUILDDIR)/%.o: $(SRCDIR)/%.asm
	@mkdir -p $(BUILDDIR)
	$(AS) $(ASFLAGS) $< -o $@

# Creating the ISO (Requires xorriso and grub-pc-bin in WSL2)
$(ISO): $(KERNEL) $(INITRD) $(SRCDIR)/grub.cfg
	rm -rf isodir
	@mkdir -p isodir/boot/grub
	cp $(KERNEL) isodir/boot/myos.bin
	cp $(INITRD) isodir/boot/initrd.tar
	cp $(SRCDIR)/grub.cfg isodir/boot/grub/grub.cfg
	grub-mkrescue -o $(ISO) isodir

$(INITRD):
	tar -cf $(INITRD) -C fs .

# Run the full ISO
run: $(ISO)
	qemu-system-x86_64 -cdrom $(ISO) -m 256M -vga std -serial stdio -no-reboot -no-shutdown

# Fast Test (Direct Kernel Boot) - Best for development
test: $(KERNEL) $(INITRD)
	qemu-system-x86_64 -kernel $(KERNEL) -initrd $(INITRD) -m 256M -vga std -serial stdio -no-reboot -no-shutdown

clean:
	rm -rf $(BUILDDIR) isodir $(ISO) $(INITRD)