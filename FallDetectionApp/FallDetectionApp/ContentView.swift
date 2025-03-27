//
//  ContentView.swift
//  FallDetectionApp
//
//

import SwiftUI
import CoreBluetooth
import Accelerate

// Stuck on Calibration Page
struct ContentView: View {
    @ObservedObject var bluetoothViewModel = BluetoothViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                Text(bluetoothViewModel.isConnected ? "Connected to ESP32" : "Connecting...")
                    .font(.headline)
                    .padding()

                if let sensor = bluetoothViewModel.liveSensorData {
                    HeatmapView(sensorData: sensor)
                        .environmentObject(bluetoothViewModel)
                    HStack(spacing: 0) {
                        ForEach(0..<100) { i in
                            let value = CGFloat(i) / 99.0
                            Rectangle()
                                .fill(Color(heatValue: value))
                        }
                    }
                    .frame(height: 20)
                    .cornerRadius(5)
                    .overlay(
                        HStack {
                            Text("Low").foregroundColor(.black).font(.caption)
                            Spacer()
                            Text("High").foregroundColor(.black).font(.caption)
                        }
                        .padding(.horizontal, 8)
                    )
                    .padding(.top)
                } else {
                    Text("Waiting for sensor data...")
                        .padding()
                }

                NavigationLink("Go to Calibration", destination: CalibrationView(bluetoothViewModel: bluetoothViewModel))
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

// Simulated Data
//struct ContentView: View {
//    @StateObject var fakeViewModel = FakeViewModel()
//
//    var body: some View {
//        VStack {
//            Text("Simulating Fake Data...")
//                .font(.headline)
//                .padding()
//
//            if let sensor = fakeViewModel.liveSensorData {
//                HeatmapView(sensorData: sensor)
//                    .environmentObject(fakeViewModel)
//            }
//
//            if let fall = fakeViewModel.detectedFallMessage {
//                Text(fall)
//                    .font(.title2)
//                    .foregroundColor(.red)
//                    .bold()
//                    .padding()
//            }
//
//            Spacer()
//        }
//        .padding()
//    }
//}


#Preview {
    ContentView()
}
