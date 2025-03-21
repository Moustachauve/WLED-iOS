//
//  MenuBar.swift
//  wled-native-osx
//
//  Created by Robert Brune on 20.03.25.
//

import Foundation
import SwiftUI

struct MenuBar: View {
    
    private static let sort = [
        SortDescriptor(\Device.name, comparator: .localized, order: .forward)
    ]
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(sortDescriptors: sort, animation: .default)
    private var devices: FetchedResults<Device>
    
    @ViewBuilder
    var body: some View {
        List(devices) { device in
            HStack {
                ActiveToogle(device: device)
                Text(device.displayName)
                    .font(.headline.leading(.tight))
                
                Icons.wifi(isOnline: device.isOnline, signalStrength: Int(device.networkRssi))
                
                if (device.updateAvailable) {
                    Icons.update
                }
                Spacer()
                PresetSelector(device: device)
                    .labelsHidden()
                    .frame(alignment: .trailing)
            }
        }
        openWindowButton
            .padding()
    }
    
    
    var openWindowButton: some View {
        Button {
            //  Dismisses the menu bar window
            dismiss()
            //  Opens a new main window
            openWindow(id: WindowIds.main.rawValue)
            //  Brings the window to the foreground
            NSApplication.shared.activate()
        } label: {
            Text("Show Window")
        }
    }
}
