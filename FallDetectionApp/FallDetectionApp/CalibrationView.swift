//
//  CalibrationView.swift
//  FallDetectionApp
//
//

import SwiftUI

struct CalibrationView: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @State private var isCalibrating = false
    @State private var calibrationCountdown = 3
    @State private var calibrated = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Calibration")
                .font(.largeTitle)

            if calibrated {
                Text("✅ Calibration complete")
            } else if isCalibrating {
                Text("Calibrating... \(calibrationCountdown)")
            } else {
                Text("Press start and stand still for 3 seconds.")
            }

            Button("Start Calibration") {
                startCalibration()
            }
            .disabled(isCalibrating)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }

    func startCalibration() {
        isCalibrating = true
        calibrated = false
        calibrationCountdown = 3
        bluetoothViewModel.clearCalibration()

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if calibrationCountdown > 0 {
                calibrationCountdown -= 1
            } else {
                timer.invalidate()
                isCalibrating = false
                calibrated = true
                bluetoothViewModel.finalizeCalibration()
            }
        }
    }
}
