//
//  FakeViewModel.swift
//  FallDetectionApp
//
//

import SwiftUI
import UIKit

class FakeViewModel: ObservableObject {
    @Published var liveSensorData: SensorData?
    @Published var sensorHistory: [SensorData] = []

    // Simulated calibration max values (already normalized to 0–1)
    @Published var calibratedMaxValues: [CGFloat] = [0.6, 0.6, 0.4, 0.5, 0.5, 0.5, 0.3, 0.3]
    @Published var detectedFallMessage: String? = nil

    private var timer: Timer?
    private var t: Double = 0.0

    init() {
        startSimulatedData()
    }

    func startSimulatedData() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.t += 0.1

            // Simulate a backward fall between 5s–7s
            let isBackwardFall = self.t > 5 && self.t < 7

            // Values are now between 0.0–1.0 to match normalized real data
            let pressures: [CGFloat] = [
                isBackwardFall ? CGFloat.random(in: 0.9...1.0) : CGFloat.random(in: 0.4...0.6), // heel left
                isBackwardFall ? CGFloat.random(in: 0.9...1.0) : CGFloat.random(in: 0.4...0.6), // heel right
                CGFloat.random(in: 0.3...0.4),  // arch
                CGFloat.random(in: 0.4...0.5),  // ball left
                CGFloat.random(in: 0.4...0.5),  // ball middle
                CGFloat.random(in: 0.4...0.5),  // ball right
                isBackwardFall ? CGFloat.random(in: 0.05...0.1) : CGFloat.random(in: 0.2...0.3), // toe right
                isBackwardFall ? CGFloat.random(in: 0.05...0.1) : CGFloat.random(in: 0.2...0.3)  // toe left
            ]

            let sensor = SensorData(time: self.t, pressures: pressures)
            self.sensorHistory.append(sensor)
            self.liveSensorData = sensor

            if self.sensorHistory.count > 30 {
                self.runCombinedFallDetection()
            }
        }
    }

    func runCombinedFallDetection() {
        let index = sensorHistory.count - 1
        let maxValues = calibratedMaxValues
        let current = sensorHistory[index].pressures

        let heelValues = sensorHistory.map { Double($0.pressures[0]) }
        let toeValues = sensorHistory.map { Double($0.pressures[7]) }

        let smoothedHeel = smooth(values: heelValues, windowSize: 21)
        let smoothedToe = smooth(values: toeValues, windowSize: 21)

        let slopeHeel = computeSlopes(values: smoothedHeel)
        let slopeToe = computeSlopes(values: smoothedToe)

        let heelSlope = slopeHeel[index]
        let toeSlope = slopeToe[index]

        let thresholdHeel = stdDev(slopeHeel) * 3
        let thresholdToe = stdDev(slopeToe) * 3

        let slopeTrigger = abs(heelSlope) > thresholdHeel || abs(toeSlope) > thresholdToe

        let toeIndices = [6, 7]
        let heelIndices = [0, 1]

        let toeExceeded = toeIndices.contains { current[$0] > maxValues[$0] * 1.5 }
        let heelDropped = heelIndices.contains { current[$0] < maxValues[$0] * 0.5 }
        let heelExceeded = heelIndices.contains { current[$0] > maxValues[$0] * 1.5 }
        let toeDropped = toeIndices.contains { current[$0] < maxValues[$0] * 0.5 }

        if slopeTrigger && toeExceeded && heelDropped {
            showFall(message: "🚨 Simulated Forward Fall Detected")
        } else if slopeTrigger && heelExceeded && toeDropped {
            showFall(message: "🚨 Simulated Backward Fall Detected")
        }
    }

    func showFall(message: String) {
        detectedFallMessage = message
        vibrate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.detectedFallMessage = nil
        }
    }

    func vibrate() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Helpers

    func smooth(values: [Double], windowSize: Int) -> [Double] {
        guard values.count >= windowSize else { return values }
        var result = [Double](repeating: 0.0, count: values.count)
        let half = windowSize / 2

        for i in 0..<values.count {
            var sum = 0.0
            var count = 0
            for j in -half...half {
                let idx = i + j
                if idx >= 0 && idx < values.count {
                    sum += values[idx]
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

    func stdDev(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
