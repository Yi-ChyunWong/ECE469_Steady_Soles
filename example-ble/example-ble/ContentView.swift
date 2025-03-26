import SwiftUI
import CoreBluetooth

class BluetoothViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager?
    private var esp32Peripheral: CBPeripheral?
    private var motorCharacteristic: CBCharacteristic?
    
    @Published var isConnected = false
    @Published var receivedData: String = ""

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
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject private var bluetoothViewModel = BluetoothViewModel()
    
    var body: some View {
        VStack {
            Text(bluetoothViewModel.isConnected ? "Connected to ESP32" : "Connecting...")
                .font(.headline)
                .padding()
            
            Button(action: { bluetoothViewModel.sendCommand("ON") }) {
                Text("Turn Motor ON")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            Button(action: { bluetoothViewModel.sendCommand("OFF") }) {
                Text("Turn Motor OFF")
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            // Display the received string
            VStack {
                Text("Received Data: \(bluetoothViewModel.receivedData)")
                    .font(.body)
                    .padding()
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
