//
//  ActiveToogle.swift
//  wled-native
//
//  Created by Robert Brune on 20.03.25.
//

import Foundation
import SwiftUI

struct ActiveToogle: View {
    
    @ObservedObject var device: Device
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Toggle("Turn On/Off", isOn: Binding(get: {device.isPoweredOn}, set: {
            device.isPoweredOn = $0
            let postParam = WLEDStateChange(isOn: $0)
            print("device \(device.address ?? "?") toggled \(postParam)")
            Task {
                await device.getRequestManager().addRequest(WLEDChangeStateRequest(state: postParam))
            }
        }))
            .tint(device.displayColor(colorScheme: colorScheme))
            .labelsHidden()
    }
}
