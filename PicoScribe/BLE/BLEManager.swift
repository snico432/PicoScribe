/*
See LICENSE.txt for licensing information.

Abstract:
Bluetooth Low Energy manager for sending transcribed text to a Pico 2 W.
Uses the Nordic UART Service (NUS).
*/

import Foundation
import CoreBluetooth

/// Nordic UART Service UUIDs — match these on your Pico 2 W firmware.
enum BLEConstants {
    static let uartServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let rxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let deviceNameFilter = "Pico"
}

enum BLEConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case failed(String)
}

@Observable
final class BLEManager: NSObject {
    var connectionState: BLEConnectionState = .disconnected
    var discoveredDevices: [CBPeripheral] = []
    var lastSentText: String?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices = []
        connectionState = .scanning
        centralManager.scanForPeripherals(withServices: [BLEConstants.uartServiceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func sendText(_ text: String) {
        guard connectionState == .connected,
              let peripheral = connectedPeripheral,
              let characteristic = rxCharacteristic,
              let data = text.data(using: .utf8) else { return }

        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse

        let maxLen: Int
        if writeType == .withoutResponse {
            maxLen = max(peripheral.maximumWriteValueLength(for: .withoutResponse), 1)
        } else {
            maxLen = max(peripheral.maximumWriteValueLength(for: .withResponse), 1)
        }

        var offset = 0
        while offset < data.count {
            let end = min(offset + maxLen, data.count)
            peripheral.writeValue(data.subdata(in: offset..<end), for: characteristic, type: writeType)
            offset = end
        }
        lastSentText = text
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            break
        case .poweredOff:
            connectionState = .failed("Bluetooth is off")
        case .unauthorized:
            connectionState = .failed("Bluetooth permission denied")
        default:
            connectionState = .failed("Bluetooth unavailable")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        guard name.localizedCaseInsensitiveContains(BLEConstants.deviceNameFilter) else { return }

        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        peripheral.discoverServices([BLEConstants.uartServiceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .failed(error?.localizedDescription ?? "Connection failed")
        connectedPeripheral = nil
        rxCharacteristic = nil
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .disconnected
        connectedPeripheral = nil
        rxCharacteristic = nil
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == BLEConstants.uartServiceUUID }) else {
            connectionState = .failed("UART service not found")
            return
        }
        peripheral.discoverCharacteristics([BLEConstants.rxCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: {
                  $0.uuid == BLEConstants.rxCharacteristicUUID
              }) else {
            connectionState = .failed("RX characteristic not found")
            return
        }
        rxCharacteristic = characteristic
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            print("BLE write error: \(error.localizedDescription)")
        }
    }
}
