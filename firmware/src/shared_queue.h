#ifndef _SHARED_QUEUE_H
#define _SHARED_QUEUE_H

#include "pico/util/queue.h"

#define Q_ELEM_SIZE 1 // In bytes
#define Q_NUM_ELEM 256

extern queue_t char_queue; 

#endif /* _SHARED_QUEUE_H */