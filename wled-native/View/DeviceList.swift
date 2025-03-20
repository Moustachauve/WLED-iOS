//
//  DeviceList.swift
//  wled-native
//
//  Created by Robert Brune on 19.03.25.
//

import SwiftUI

@available(iOS 16.0, macOS 15.0, *)
struct DeviceList: View {
    
    let devices:FetchedResults<Device>
    
    var body: some View {
        ForEach(devices) { device in
            NavigationLink(value: device) {
                DeviceListItemView()
            }
                .environmentObject(device)
                .swipeActions(allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteItems(device: device)
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
        }
    }
    
    
    private func deleteItems(device: Device) {
        withAnimation {
            if let context = device.managedObjectContext {
                context.delete(device)
                do {
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    // TODO: Resolve Error properly
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}
