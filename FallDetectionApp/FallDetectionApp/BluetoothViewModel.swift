//
//  BluetoothViewModel.swift
//  FallDetectionApp
//
//

import SwiftUI
import CoreBluetooth
import Accelerate
import UIKit

// Sensor Data Vector
struct SensorData {
    var time: Double
    var pressures: [CGFloat] // 8 sensor values
}

// Bluetooth Module
class BluetoothViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager?
    private var esp32Peripheral: CBPeripheral?
    private var motorCharacteristic: CBCharacteristic?

    @Published var isConnected = false
    @Published var receivedData: String = ""
    @Published var liveSensorData: SensorData?
    @Published var sensorHistory: [SensorData] = []

    @Published var calibrationBuffer: [[CGFloat]] = []
    @Published var calibratedMaxValues: [CGFloat]? = nil
    @Published var isCalibrating = false
    @Published var detectedFallMessage: String? = nil

    let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func sendCommand(_ command: String) {
        guard let peripheral = esp32Peripheral, let characteristic = motorCharacteristic else {
            print("No device connected")
            return
        }
        let data = command.data(using: .utf8)!
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("Sent command: \(command)")
    }

//    func parsePressureData(_ raw: String) -> SensorData? {
//        let components = raw.components(separatedBy: ",")
//        var pressures: [CGFloat] = []
//
//        for part in components {
//            let kv = part.components(separatedBy: ":")
//            if kv.count == 2, let value = Double(kv[1]) {
//                pressures.append(CGFloat(value))
//            }
//        }
//
//        guard pressures.count == 8 else { return nil }
//        let timestamp = Date().timeIntervalSince1970
//        return SensorData(time: timestamp, pressures: pressures)
//    }
    
    func parsePressureData(_ raw: String) -> SensorData? {
        //let components = raw.components(separatedBy: ",")
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ","))
        let components = cleaned.components(separatedBy: ",")
        guard components.count == 8 else { return nil }

        // Normalize values from 0–2000 to 0.0–1.0
        let values = components.compactMap { Double($0).map { CGFloat($0 / 2000.0) } }
        guard values.count == 8 else { return nil }

        // Incoming order: 2,3,4,5,6,7,8,9
        // Desired app order: 5,7,4,6,8,9,3,2
        let remap: [Int] = [3, 5, 2, 4, 6, 7, 1, 0]
        let reordered = remap.map { values[$0] }

        return SensorData(time: Date().timeIntervalSince1970, pressures: reordered)
    }

    func appendSensorData(_ data: SensorData) {
        print("📥 Appending sensor data: \(data.pressures)")
        if isCalibrating {
            calibrationBuffer.append(data.pressures)
            print("Calibrating – Appended: \(data.pressures)")
        }
        sensorHistory.append(data)
        if sensorHistory.count > 1000 {
            sensorHistory.removeFirst()
        }
        liveSensorData = data
        autoRunFallDetection()
    }

    func clearCalibration() {
        calibrationBuffer.removeAll()
        isCalibrating = true
        sendCommand("ON")
    }

    func finalizeCalibration() {
        guard !calibrationBuffer.isEmpty else {
            print("Calibration buffer is empty — no data to finalize")
            return
        }
        let sensorCount = calibrationBuffer[0].count
        var maxValues = [CGFloat](repeating: 0, count: sensorCount)

        for frame in calibrationBuffer {
            for i in 0..<sensorCount {
                maxValues[i] = max(maxValues[i], frame[i])
            }
        }

        calibratedMaxValues = maxValues
        isCalibrating = false
        print("Calibrated max values: \(maxValues)")
    }

    func autoRunFallDetection() {
        guard let maxValues = calibratedMaxValues else { return }
        guard sensorHistory.count > 20 else { return }

        let heelPressures = sensorHistory.map { Double($0.pressures[0]) }
        let toePressures = sensorHistory.map { Double($0.pressures[7]) }

        let smoothedHeel = savitzkyGolaySmooth(values: heelPressures, windowSize: 21, polynomialOrder: 3)
        let smoothedToe = savitzkyGolaySmooth(values: toePressures, windowSize: 21, polynomialOrder: 3)

        let slopeHeel = computeSlopes(values: smoothedHeel)
        let slopeToe = computeSlopes(values: smoothedToe)

        let stdDevHeel = sqrt(slopeHeel.dropFirst().reduce(0.0) { $0 + pow($1, 2) } / Double(slopeHeel.count - 1))
        let stdDevToe = sqrt(slopeToe.dropFirst().reduce(0.0) { $0 + pow($1, 2) } / Double(slopeToe.count - 1))

        let thresholdHeel = stdDevHeel * 3
        let thresholdToe = stdDevToe * 3

        let index = sensorHistory.count - 1
        let heelSlope = slopeHeel[index]
        let toeSlope = slopeToe[index]

        let slopeTrigger = abs(heelSlope) > thresholdHeel || abs(toeSlope) > thresholdToe

        let current = sensorHistory[index].pressures
        let toeIndices = [6, 7]
        let heelIndices = [0, 1]

        let toeExceeded = toeIndices.contains { current[$0] > maxValues[$0] * 1.5 }
        let heelDropped = heelIndices.contains { current[$0] < maxValues[$0] * 0.5 }
        let heelExceeded = heelIndices.contains { current[$0] > maxValues[$0] * 1.5 }
        let toeDropped = toeIndices.contains { current[$0] < maxValues[$0] * 0.5 }

        if slopeTrigger && toeExceeded && heelDropped {
            detectedFallMessage = "🚨 Forward Fall Detected"
            triggerAlertFeedback()
        } else if slopeTrigger && heelExceeded && toeDropped {
            detectedFallMessage = "🚨 Backward Fall Detected"
            triggerAlertFeedback()
        }
    }

    func triggerAlertFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // Helper Functions
    func savitzkyGolaySmooth(values: [Double], windowSize: Int, polynomialOrder: Int) -> [Double] {
        guard values.count >= windowSize else { return values }
        var result = [Double](repeating: 0.0, count: values.count)
        let halfWindow = windowSize / 2

        for i in 0..<values.count {
            var sum = 0.0
            var count = 0
            for j in -halfWindow...halfWindow {
                let index = i + j
                if index >= 0 && index < values.count {
                    sum += values[index]
                    count += 1
                }
            }
            result[i] = sum / Double(count)
        }
        return result
    }

    func computeSlopes(values: [Double]) -> [Double] {
        var slopes = [Double](repeating: 0.0, count: values.count)
        for i in 1..<values.count {
            slopes[i] = values[i] - values[i - 1]
        }
        return slopes
    }
}

extension BluetoothViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is powered on. Scanning for ESP32...")
            self.centralManager?.scanForPeripherals(withServices: [serviceUUID])
        } else {
            print("Bluetooth is not available.")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if esp32Peripheral == nil {
            print("ESP32 found. Connecting...")
            esp32Peripheral = peripheral
            esp32Peripheral?.delegate = self
            centralManager?.stopScan()
            centralManager?.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            print("Connected to ESP32!")
            self.isConnected = true
        }
        peripheral.discoverServices([serviceUUID])
    }
}

extension BluetoothViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            print("Service found. Discovering characteristics...")
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == characteristicUUID {
            motorCharacteristic = characteristic
            print("Characteristic found!")

            // Enable notifications
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribed to notifications!")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == characteristicUUID, let data = characteristic.value {
            let stringData = String(data: data, encoding: .utf8) ?? "Unreadable Data"
            DispatchQueue.main.async {
                self.receivedData = stringData
                print("Received raw data: \(data)")
                print("Received string data: \(stringData)")
                let arrayData = self.parsePressureData(stringData)
                if let sensor = arrayData {
                    print("Parsed sensor data: \(sensor)")
                    self.appendSensorData(sensor)
                } else {
                    print("⚠️ parsePressureData returned nil for string: \(stringData)")
                }
            }
        }
    }
}
