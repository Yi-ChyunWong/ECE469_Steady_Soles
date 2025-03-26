//
//  FallDetection.swift
//  PressureVisualizer
//
//  Created by Rachel Odonkor on 3/6/25.
//

import Foundation
import Accelerate

// Simulated Pressure Sensor Data Structure
struct SensorData {
    var time: Double
    var heelPressure: Double
    var midfootPressure: Double
    var forefootPressure: Double
}

// Generate Dummy Data (Simulating Standing, Leaning, and Falling)
func generateDummySensorData(samples: Int) -> [SensorData] {
    var data: [SensorData] = []
    let fallStart = samples / 2  // Assume fall starts at the midpoint
    let fallDuration = samples / 10  // Gradual fall duration
    
    for i in 0..<samples {
        let time = Double(i) * 0.1 // Simulated time (every 0.1s)
        var heel = 50.0
        var midfoot = 30.0
        var forefoot = 20.0
        
        if i >= fallStart && i < fallStart + fallDuration {
            let factor = Double(i - fallStart) / Double(fallDuration) // Smooth transition factor
            heel += 80 * factor
            midfoot += 40 * factor
            forefoot += 60 * factor
        } else if i >= fallStart + fallDuration {
            heel += 80
            midfoot += 40
            forefoot += 60
        }
        
        data.append(SensorData(time: time, heelPressure: heel, midfootPressure: midfoot, forefootPressure: forefoot))
    }
    return data
}

// Apply Moving Average Filter for Smoothing
func smoothData(values: [Double], windowSize: Int) -> [Double] {
    guard values.count >= windowSize else { return values }
    var smoothed = [Double](repeating: 0.0, count: values.count)
    var sum: Double = 0.0
    
    for i in 0..<values.count {
        sum += values[i]
        if i >= windowSize {
            sum -= values[i - windowSize]
        }
        smoothed[i] = sum / Double(min(i + 1, windowSize))
    }
    return smoothed
}

// Compute Slopes
func computeSlopes(values: [Double]) -> [Double] {
    var slopes = [Double](repeating: 0.0, count: values.count)
    for i in 1..<values.count {
        slopes[i] = values[i] - values[i - 1]
    }
    return slopes
}

// Fall Detection Based on Threshold
func detectFalls(slopes: [Double], threshold: Double) -> [Int] {
    return slopes.enumerated().compactMap { index, slope in
        return abs(slope) > threshold ? index : nil
    }
}

// Main Execution
let numSamples = 1000
let sensorData = generateDummySensorData(samples: numSamples)
let heelPressures = sensorData.map { $0.heelPressure }
let smoothedHeel = smoothData(values: heelPressures, windowSize: 21)
let slopeHeel = computeSlopes(values: smoothedHeel)
let fallEvents = detectFalls(slopes: slopeHeel, threshold: 3.0)

//print("Detected Fall Events at indices: \(fallEvents)")
