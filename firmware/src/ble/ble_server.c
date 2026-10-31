#include "ble_server.h"

#include "btstack.h"
#include "pico/btstack_cyw43.h"
#include "pico/cyw43_arch.h"
#include "pico/multicore.h"
#include "pico/stdlib.h"
#include "pico/util/queue.h"

#include "debug_log.h"
#include "hid_keyboard.h"
#include "picoscribe.h"
#include "shared_queue.h"

#define APP_AD_FLAGS 0x06
#define NUS_RX_VALUE_HANDLE ATT_CHARACTERISTIC_6E400002_B5A3_F393_E0A9_E50E24DCCA9E_01_VALUE_HANDLE

static uint8_t adv_data[] = {
    // Flags general discoverable
    0x02,
    BLUETOOTH_DATA_TYPE_FLAGS,
    APP_AD_FLAGS,
    0x0B,
    BLUETOOTH_DATA_TYPE_COMPLETE_LOCAL_NAME,
    'P',
    'i',
    'c',
    'o',
    'S',
    'c',
    'r',
    'i',
    'b',
    'e',
};

/* Nordic UART Service UUID 6E400001-B5A3-F393-E0A9-E50E24DCCA9E (LE). */
static uint8_t scan_resp_data[] = {
    0x11, BLUETOOTH_DATA_TYPE_COMPLETE_LIST_OF_128_BIT_SERVICE_CLASS_UUIDS,
    0x9E, 0xCA,
    0xDC, 0x24,
    0x0E, 0xE5,
    0xA9, 0xE0,
    0x93, 0xF3,
    0xA3, 0xB5,
    0x01, 0x00,
    0x40, 0x6E,
};

static const uint8_t adv_data_len = sizeof(adv_data);
static const uint8_t scan_resp_data_len = sizeof(scan_resp_data);

static btstack_packet_callback_registration_t hci_event_callback_registration;

static void init_and_start_advertising() {
    bd_addr_t local_addr;
    gap_local_bd_addr(local_addr);
    DEBUG_LOG("BLE ready — advertising as PicoScribe @ %s.\n", bd_addr_to_str(local_addr));

    uint16_t adv_int_min = 800;
    uint16_t adv_int_max = 800;
    uint8_t adv_type = 0;
    bd_addr_t null_addr;
    memset(null_addr, 0, 6);
    gap_advertisements_set_params(adv_int_min, adv_int_max, adv_type, 0, null_addr, 0x07, 0x00);
    assert(adv_data_len <= 31);
    assert(scan_resp_data_len <= 31);
    gap_advertisements_set_data(adv_data_len, adv_data);
    gap_scan_response_set_data(scan_resp_data_len, scan_resp_data);
    gap_advertisements_enable(1);
}

static void packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    UNUSED(size);
    UNUSED(channel);
    if (packet_type != HCI_EVENT_PACKET)
        return;

    uint8_t event_type = hci_event_packet_get_type(packet);
    switch (event_type) {
        case BTSTACK_EVENT_STATE:
            if (btstack_event_state_get_state(packet) != HCI_STATE_WORKING)
                return;
            init_and_start_advertising();
            break;
        case HCI_EVENT_DISCONNECTION_COMPLETE:
            DEBUG_LOG("BLE disconnected\n");
            gap_advertisements_enable(1);
            break;
        default:
            break;
    }
}

static uint16_t att_read_callback(hci_con_handle_t connection_handle, uint16_t att_handle,
                                  uint16_t offset, uint8_t *buffer, uint16_t buffer_size) {
    UNUSED(connection_handle);
    UNUSED(att_handle);
    UNUSED(offset);
    UNUSED(buffer);
    UNUSED(buffer_size);

    return 0;
}

static int att_write_callback(hci_con_handle_t connection_handle, uint16_t att_handle,
                              uint16_t transaction_mode, uint16_t offset, uint8_t *buffer,
                              uint16_t buffer_size) {
    UNUSED(connection_handle);
    UNUSED(att_handle);
    UNUSED(transaction_mode);
    UNUSED(offset);

    if (att_handle != NUS_RX_VALUE_HANDLE)
        return 0;

    for (int i = 0; i < buffer_size; i++) {
        if (!queue_try_add(&char_queue, &buffer[i])) {
            DEBUG_LOG("Character Queue Overflow! Character dropped: '%c'\n", buffer[i]);
            break;
        }
    }

    return 0;
}

int run_btstack_ble_loop(void) {
    stdio_init_all();

    if (cyw43_arch_init()) {
        DEBUG_LOG("Failed to initialise cyw43_arch\n");
        return -1;
    }

    l2cap_init();
    sm_init();

    att_server_init(profile_data, att_read_callback, att_write_callback);

    hci_event_callback_registration.callback = &packet_handler;
    hci_add_event_handler(&hci_event_callback_registration);

    att_server_register_packet_handler(packet_handler);

    hci_power_control(HCI_POWER_ON);

    while (1) {
        async_context_poll(cyw43_arch_async_context());
        async_context_wait_for_work_until(cyw43_arch_async_context(), at_the_end_of_time);
    }

    return 0;
}