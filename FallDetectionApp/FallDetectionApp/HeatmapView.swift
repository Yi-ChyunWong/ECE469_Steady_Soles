//
//  HeatmapView.swift
//  FallDetectionApp
//
//

import SwiftUI
import CoreBluetooth
import Accelerate

struct HeatmapView: View {
    var sensorData: SensorData
    @EnvironmentObject var viewModel: BluetoothViewModel // or BluetoothViewModel or FakeViewModel

//    let positions: [CGPoint] = [
//        CGPoint(x: 110, y: 530), // Heel left
//        CGPoint(x: 190, y: 530), // Heel right
//        CGPoint(x: 180, y: 390), // Arch
//        CGPoint(x: 90, y: 230),  // Ball left
//        CGPoint(x: 155, y: 250), // Ball middle
//        CGPoint(x: 215, y: 270), // Ball right
//        CGPoint(x: 280, y: 160), // Toe right
//        CGPoint(x: 65, y: 90)    // Toe left
//    ]
//
//    func rotateSensor(_ position: CGPoint) -> Double {
//        if position == CGPoint(x: 280, y: 160) { return -30 } // Rotate Toe Right
//        if position == CGPoint(x: 65, y: 90) { return 10 }    // Rotate Toe Left
//        return 0
//    }
    let positions: [CGPoint] = [
        CGPoint(x: 65, y: 90),   // Toe Left
        CGPoint(x: 280, y: 160), // Toe Right
        CGPoint(x: 90, y: 230),  // Ball Left
        CGPoint(x: 155, y: 250), // Ball Middle
        CGPoint(x: 215, y: 270), // Ball Right
        CGPoint(x: 180, y: 390), // Arch
        CGPoint(x: 110, y: 530), // Heel Left
        CGPoint(x: 190, y: 530)  // Heel Right
    ]
    
    func rotateSensor(_ position: CGPoint) -> Double {
        if position == CGPoint(x: 280, y: 160) { return -30 } // Rotate Toe Right
        if position == CGPoint(x: 65, y: 90) { return 10 }    // Rotate Toe Left
        return 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("ShoeSole")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                ForEach(0..<sensorData.pressures.count, id: \.self) { i in
//                    let calibratedMax = viewModel.calibratedMaxValues ?? Array(repeating: 1.0, count: sensorData.pressures.count)
//                    let calibrated = max(calibratedMax[i], 0.8)
//
//                    let value = sensorData.pressures[i]
//                    let normalized = min(max(value / calibrated, 0.0), 1.0)
                    
                    let value = sensorData.pressures[i]
                    let normalized = min(max(value, 0.0), 1.0)

                    Ellipse()
                        .fill(Color(heatValue: normalized))
                        .frame(width: 40, height: 60)
                        .position(positions[i])
                        .rotationEffect(.degrees(rotateSensor(positions[i])))
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 0.3), value: normalized)
                }
            }
        }
        .frame(width: 300, height: 600)
        .scaleEffect(x: -1, y: 1)
    }
}

extension Color {
    init(heatValue: CGFloat) {
        let clamped = min(max(heatValue, 0.0), 1.0)

        // Blue (0,0,1) → Purple (0.5,0,0.5) → Red (1,0,0)
        let red = clamped < 0.5 ? clamped * 2.0 : 1.0
        let blue = clamped < 0.5 ? 1.0 : 2.0 * (1.0 - clamped)
        let green: CGFloat = 0.0

        self = Color(red: red, green: green, blue: blue)
    }
}
