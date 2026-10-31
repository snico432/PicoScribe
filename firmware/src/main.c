#include "pico/cyw43_arch.h"
#include "pico/multicore.h"
#include "pico/stdlib.h"
#include "pico/util/queue.h"

#include <stdio.h>

#include "ble_server.h"
#include "hid_keyboard.h"
#include "shared_queue.h"

queue_t char_queue;

int main() {
    queue_init(&char_queue, Q_ELEM_SIZE, Q_NUM_ELEM);

    multicore_launch_core1(run_hid_loop);

    run_btstack_ble_loop();

    return 0;
}