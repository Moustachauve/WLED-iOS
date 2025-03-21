//
//  BrightnessSlider.swift
//  wled-native
//
//  Created by Robert Brune on 20.03.25.
//

import Foundation
import SwiftUI

struct BrightnesSlider: View {
    
    @State private var brightness: Double = 0.0
    @ObservedObject var device: Device
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Slider(
            value: $brightness,
            in: 0...255,
            onEditingChanged: { editing in
                print("device \(device.address ?? "?") brightness is changing: \(editing) - \(brightness)")
                if (!editing) {
                    let postParam = WLEDStateChange(brightness: Int64(brightness))
                    Task {
                        await device.getRequestManager().addRequest(WLEDChangeStateRequest(state: postParam))
                    }
                }
            }
        )
            .tint(device.displayColor(colorScheme: colorScheme))
            .onAppear() {
                brightness = Double(device.brightness)
            }
            .onChange(of: device.brightness) { brightness in
                self.brightness = Double(device.brightness)
            }
    }
}
