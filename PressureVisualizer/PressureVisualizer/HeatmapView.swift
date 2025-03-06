//
//  HeatmapView.swift
//  PressureVisualizer
//
//  Created by Rachel Odonkor on 3/1/25.
//

import SwiftUI

struct HeatmapView: View {
    @State private var sensorData: [CGPoint: CGFloat] = [
        CGPoint(x: 110, y: 530): 0.2, // Heel left
        CGPoint(x: 190, y: 530): 0.2, // Heel right
        CGPoint(x: 180, y: 390): 0.4, // Arch
        CGPoint(x: 90, y: 230): 0.6, // Ball left
        CGPoint(x: 155, y: 250): 0.6, // Ball middle
        CGPoint(x: 215, y: 270): 0.6, // Ball right
        CGPoint(x: 280, y: 160): 0.85, // Toe right
        CGPoint(x: 65, y: 90): 0.9  // Toe left
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Shoe outline as the background
                Image("ShoeSole")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Sensor points with elliptical shape
                ForEach(sensorData.keys.sorted(by: { $0.y < $1.y }), id: \.self) { position in
                    Ellipse()
                        .fill(Color(heatValue: sensorData[position] ?? 0))
                        .frame(width: 40, height: 60)
                        .position(position)
                        .rotationEffect(Angle.degrees(rotateSensor(position))) // Apply rotation conditionally
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 0.3), value: sensorData)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(x: -1, y: 1)
        }
        .frame(width: 300, height: 600) // Match shoe image size
    }
    
    // Function to determine if a sensor should be rotated
    func rotateSensor(_ position: CGPoint) -> Double {
        if position == CGPoint(x: 280, y: 160) { return -30 } // Rotate Toe Right
        if position == CGPoint(x: 65, y: 90) { return 10 }  // Rotate Toe Left
        return 0 // Default rotation (no tilt)
    }
}

// Color Mapping
extension Color {
    init(heatValue: CGFloat) {
        self = Color(red: heatValue, green: 0, blue: 1 - heatValue)
    }
}

#Preview {
    HeatmapView()
}
