# PicoScribe

[![PicoScribe demo](https://img.youtube.com/vi/fRu5Mnwbabs/maxresdefault.jpg)](https://youtu.be/fRu5Mnwbabs)

**Speak on your iPhone; text appears as a USB keyboard on another computer via a Raspberry Pi Pico 2 W.**

Cross-platform systems project: on-device speech-to-text on iPhone, BLE to a Pico 2 W, USB HID keyboard on the host — no cloud STT, no Wi‑Fi, no software on the target machine.

```text
iPhone mic  →  SpeechAnalyzer  →  BLE (Nordic UART)  →  Pico 2 W  →  USB HID keyboard  →  host PC
```


## Why it matters

The host only needs a USB port, so voice typing works where normal apps can’t:

- Machines with no on-device speech APIs
- Locked-down devices where you can’t install software
- Offline or air-gapped hosts with no network path for cloud STT

Privacy by design: transcription stays on the phone; text reaches the Pico over BLE.

## Tech stack

| Layer | Technologies |
|-------|----------------|
| iPhone app | SwiftUI, SpeechAnalyzer, CoreBluetooth |
| Pico 2 W Firmware | C, Pico SDK, BTstack (BLE NUS), TinyUSB (HID) |

## What I built

- Live on-device transcription with Apple’s SpeechAnalyzer
- BLE Nordic UART transport (phone → Pico)
- Pico firmware that advertises as **PicoScribe**, receives ASCII characters over BLE, and types them as a USB HID keyboard
- Monorepo packaging the SwiftUI app and Pico firmware together

## Design note: transport

BLE is the default — no network, fits the locked-down / offline cases above.

A Wi‑Fi alternative (lwIP + WebSocket) is possible later:

| Mode | Upside | Downside |
|------|--------|----------|
| Station (client) | Uses an existing LAN | Needs a local network |
| Access point | No external router | Phone typically loses cellular/internet on the Pico’s AP |

## Repo layout

| Path | What it is |
|------|------------|
| [`PicoScribe/`](PicoScribe/) | iPhone SwiftUI app (`App/`, `BLE/`, `Transcription/`, `Views/`, `Utilities/`) |
| [`firmware/`](firmware/) | Pico 2 W BLE → USB HID dongle — see [`firmware/README.md`](firmware/README.md) |

## Build (for running it yourself)

### iPhone app

1. Open `PicoScribe.xcodeproj` in Xcode and set your development team.
2. Run on a physical iPhone (BLE needs real hardware).
3. Grant microphone and Bluetooth permissions when prompted.

The app scans for NUS peripherals whose name contains `Pico`, then writes finalized transcript chunks as ASCII characters to the NUS RX characteristic. See [`PicoScribe/BLE/BLEManager.swift`](PicoScribe/BLE/BLEManager.swift).

### Firmware
 
See [`firmware/README.md`](firmware/README.md).

## Credits

- Speech UI / analyzer portions started from Apple’s WWDC25 session 277 sample: [Bring advanced speech-to-text capabilities to your app with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277).
- Pico firmware and Apple-app BLE bridge are part of this PicoScribe project.

See [LICENSE.txt](LICENSE.txt) for terms and attribution.
