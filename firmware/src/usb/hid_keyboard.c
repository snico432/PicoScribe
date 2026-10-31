// Based on
// https://github.com/hathach/tinyusb/blob/master/examples/device/hid_generic_inout/src/main.c

#include "hid_keyboard.h"

#include "bsp/board_api.h"
#include "pico/multicore.h"
#include "pico/util/queue.h"
#include "tusb.h"

#include <stdlib.h>
#include <string.h>

#include "debug_log.h"
#include "shared_queue.h"
#include "usb_descriptors.h"

static const uint8_t ascii_to_hid[128][2] = {HID_ASCII_TO_KEYCODE};

//--------------------------------------------------------------------+
// USB HID
//--------------------------------------------------------------------+

// Invoked when received GET_REPORT control request
// Application must fill buffer report's content and return its length.
// Return zero will cause the stack to STALL request
uint16_t tud_hid_get_report_cb(uint8_t itf, uint8_t report_id, hid_report_type_t report_type,
                               uint8_t *buffer, uint16_t reqlen) {
    (void)itf;
    (void)report_id;
    (void)report_type;
    (void)buffer;
    (void)reqlen;

    return 0;
}

// Invoked when received SET_REPORT control request or
// received data on OUT endpoint ( Report ID = 0, Type = 0 )
void tud_hid_set_report_cb(uint8_t itf, uint8_t report_id, hid_report_type_t report_type,
                           uint8_t const *buffer, uint16_t bufsize) {
    // This example doesn't use multiple report and report ID
    (void)itf;
    (void)report_id;
    (void)report_type;
    (void)buffer;
    (void)bufsize;
}

static int convert_ascii_to_hid(unsigned char ch, uint8_t *modifier, uint8_t *keycode) {
    /* Skip UTF-8 continuation / non-ASCII for now (US layout only). */
    if (ch >= 0x80) {
        return -1;
    }

    *modifier = ascii_to_hid[ch][0] ? KEYBOARD_MODIFIER_LEFTSHIFT : 0;
    uint8_t mapped_keycode = ascii_to_hid[ch][1];
    if (!mapped_keycode) {
        return -1;
    }
    *keycode = mapped_keycode;
    return 0;
}

static void try_send_hid_keyboard_report(void) {
    if (!tud_hid_ready()) {
        return;
    }

    static bool has_keyboard_key = false;

    if (has_keyboard_key) {
        // send empty key report if previously has key pressed
        tud_hid_keyboard_report(REPORT_ID_KEYBOARD, 0, NULL);
        has_keyboard_key = false;
        return;
    }

    unsigned char ch;
    if(!queue_try_remove(&char_queue, &ch)) { // Returns true if successful, false if failed
        return;
    }

    uint8_t keycodes[6] = {0};
    uint8_t modifier = 0;
    int res = convert_ascii_to_hid(ch, &modifier,
                               keycodes); // keycodes is the first element of the keycodes array

    if (res < 0) {
        DEBUG_LOG("Error converting '%c' to HID keycode + modifier.\n", ch);
        return;
    }

    tud_hid_keyboard_report(REPORT_ID_KEYBOARD, modifier, keycodes);
    has_keyboard_key = true;
}

void hid_task(void) {
    static uint32_t start_ms = 0;
    if (board_millis() - start_ms < HID_EP_INTERVAL_MS) {
        return;
    }
    start_ms += HID_EP_INTERVAL_MS;

    try_send_hid_keyboard_report();
}

void run_hid_loop(void) {
    board_init();

    tusb_rhport_init_t dev_init = {.role = TUSB_ROLE_DEVICE, .speed = TUSB_SPEED_AUTO};
    tusb_init(BOARD_TUD_RHPORT, &dev_init);

    if (board_init_after_tusb) {
        board_init_after_tusb();
    }

    while (1) {
        tud_task();
        hid_task();
    }
}
