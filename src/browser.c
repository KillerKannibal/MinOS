#include "browser.h"
#include "string.h"

char browser_url[BROWSER_MAX_URL];
char browser_content[BROWSER_MAX_CONTENT];

void browser_init() {
    strcpy(browser_url, "http://exile.os");
    strcpy(browser_content, "Exile Explorer\n==============\n\nWelcome to your gateway to the web.\n\nCurrently, Layer 2 (Ethernet) is active.\nType 'http://exile.os' or 'http://about' in the address bar above and press Enter.");
}

void browser_navigate(const char* url) {
    // In a future update, this will trigger ARP -> IP -> TCP -> HTTP GET
    if (strcmp(url, "http://exile.os") == 0) {
        strcpy(browser_content, "ExileOS Home\n------------\nWelcome to the local portal.\n\n[System Status]\n- Network: Ready (RTL8139)\n- Storage: TAR RAMDisk\n- User: God Mode\n\nThis page is served locally by the kernel.");
    } 
    else if (strcmp(url, "http://about") == 0) {
        strcpy(browser_content, "About Exile Explorer\n--------------------\nVersion: 0.1 (Pre-Alpha)\nEngine: ExileHTML (Internal)\n\nThis browser will eventually support full HTTP/1.1 requests over your USB-tethered connection.");
    }
    else {
        strcpy(browser_content, "Error 404: Not Found\n--------------------\n\nThe URL ");
        strcat(browser_content, url);
        strcat(browser_content, " could not be resolved.\n\nNote: External DNS and TCP are not yet implemented. Try 'http://exile.os'.");
    }
}

void browser_handle_key(char c) {
    int len = strlen(browser_url);

    if (c == '\b') {
        if (len > 7) { // Don't delete "http://"
            browser_url[len - 1] = '\0';
        }
    } 
    else if (c == '\n') {
        browser_navigate(browser_url);
    } 
    else if (c >= 32 && c <= 126) {
        if (len < BROWSER_MAX_URL - 1) {
            browser_url[len] = c;
            browser_url[len + 1] = '\0';
        }
    }
}