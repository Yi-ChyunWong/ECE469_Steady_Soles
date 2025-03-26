//
//  ContentView.swift
//  PressureVisualizer
//
//  Created by Rachel Odonkor on 3/1/25.
//

//import SwiftUI
//
//struct ContentView: View {
//   var body: some View {
//        HeatmapView() // Display the heatmap
//    }
//}

//#Preview {
//   ContentView()
//}

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            HeatmapView()
            Button("Run Fall Detection") {
                let numSamples = 1000
                let sensorData = generateDummySensorData(samples: numSamples)
                let heelPressures = sensorData.map { $0.heelPressure }
                let smoothedHeel = smoothData(values: heelPressures, windowSize: 21)
                let slopeHeel = computeSlopes(values: smoothedHeel)
                let fallEvents = detectFalls(slopes: slopeHeel, threshold: 3.0)
                print("Detected Fall Events at indices: \(fallEvents)")
            }
        }
    }
}

#Preview {
    ContentView()
}
