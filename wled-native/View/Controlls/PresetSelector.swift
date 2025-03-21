//
//  PresetSelector.swift
//  wled-native-osx
//
//  Created by Robert Brune on 21.03.25.
//

import SwiftUI

struct PresetSelector: View {
    
    @ObservedObject var device:Device
    @ObservedObject var presets:DevicePresets = DevicePresets.shared
    
    var body: some View {
        let selectionBinding = Binding {
            presets.getPreset(for: device)
        } set: { newValue in
            presets.setPreset(for: device, newPreset: newValue)
        }
        
        Picker("Presets", selection: selectionBinding) {
            Text("Undefined").tag(-1)
            ForEach(presets.presets[device]?.presets ?? [], id: \.0) { preset in
                Text(preset.1).tag(Int(preset.0))
            }
        }
        .onAppear {
            Task {
                await withTaskGroup(of: Void.self) { group in
                    device.refreshDevice(group: &group)
                }
            }
        }
    }
    
    

}

/*
#Preview {
    PresetSelector()
}
*/
