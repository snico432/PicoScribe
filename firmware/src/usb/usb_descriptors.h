#ifndef _USB_DESCRIPTORS_H
#define _USB_DESCRIPTORS_H

/* Full-speed interrupt bInterval, in milliseconds. hid_task uses the same period. */
#define HID_EP_INTERVAL_MS 10

/* TUD_HID_REPORT_DESC_KEYBOARD() has no report ID, so reports pass 0. */
#define REPORT_ID_KEYBOARD 0

#endif /* _USB_DESCRIPTORS_H */
