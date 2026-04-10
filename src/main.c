#include <stdint.h>
#include "gdt.h"
#include "idt.h"
#include "multiboot.h"
#include "shell.h"
#include "gui.h"
#include "wm.h"
#include "input.h"
#include "fs.h"
#include "pci.h"
#include "debug.h"
#include "globals.h"
#include "net.h"
#include "rtl8139.h"
#include "browser.h"
#include "rndis.h"
#include "io.h"
#include "debug.h"

// ExileOS Kernel
void ___chkstk_ms() {}
void __chkstk_ms() {}

void kernel_main(struct multiboot_info* mbinfo) {
    debug_init();
    
    // Immediate boot confirmation - kernel_main was reached
    kprint_serial("\n========================================\n");
    kprint_serial("[BOOT] ExileOS Kernel Started in Long Mode\n");
    kprint_serial("========================================\n");
    
    global_mbinfo = mbinfo;

    // Initialize CPU structures
    init_gdt();
    uint64_t rsp;
    __asm__ volatile("mov %%rsp, %0" : "=r"(rsp));
    tss.rsp0 = rsp;
    init_idt();

    // Setup Video
    if (mbinfo->flags & (1 << 12)) {
        init_vga(mbinfo);
    } else {
        kprint_serial("Error: No VBE LFB found in multiboot info\n");
        while(1);
    }

    // Early Splash Screen
    draw_rect(0, 0, screen_width, screen_height, 0x000000);
    draw_string("ExileOS is loading components...", 20, 20, 0xFFFFFF);
    screen_update();

    // Drivers & Filesystem
    draw_string(" - Initializing Filesystem", 20, 40, 0xAAAAAA);
    screen_update();

    uint32_t mod_start = 0;
    if (mbinfo->flags & (1 << 3) && mbinfo->mods_count > 0) {
        mod_start = ((multiboot_module_t*)(uintptr_t)mbinfo->mods_addr)->mod_start;
    }
    init_fs(mod_start);
    
    mouse_install();
    pci_init();

    net_init();
    rtl8139_init();
    browser_init();
    
    __asm__ volatile("sti"); // Enable hardware interrupts

    // Start Desktop
    init_desktop_buffer(wallpaper_mode);
    open_window(MODE_SHELL);

    char serial_buffer[256];
    int serial_idx = 0;
    kprint_serial("ExileOS> ");

    // Executive Loop
    while(1) {
        // Serial Shell Input
        if (inb(0x3F8 + 5) & 0x01) { // Data ready
            char c = inb(0x3F8);
            if (c == '\r' || c == '\n') {
                serial_buffer[serial_idx] = '\0';
                write_serial('\n');
                exec_command(serial_buffer);
                serial_idx = 0;
                kprint_serial("ExileOS> ");
            } else if (c == 0x08 || c == 0x7F) { // Backspace
                if (serial_idx > 0) {
                    serial_idx--;
                    write_serial(0x08);
                    write_serial(' ');
                    write_serial(0x08);
                }
            } else if (serial_idx < 255) {
                serial_buffer[serial_idx++] = c;
                write_serial(c);
            }
        }

        wm_update();      // Logic: process mouse, dragging, and focus
        
        gui_prepare_frame(); // Render: Background wallpaper
        wm_draw_all();       // Render: All open windows
        
        draw_taskbar();      // Render: System UI
        if (start_menu_open) draw_start_menu();
        
        draw_cursor(mouse_x, mouse_y); // Render: Topmost layer
        
        screen_update();     // Flush backbuffer to physical screen
    }
}
