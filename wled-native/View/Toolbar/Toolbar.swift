//
//  Toolbar.swift
//  wled-native
//
//  Created by Robert Brune on 20.03.25.
//

import Foundation
import SwiftUI

struct Toolbar: ToolbarContent {
    
    @SceneStorage(WLED.showHiddenDevices.rawValue) private var showHiddenDevices: Bool = false
    @SceneStorage(WLED.showOfflineDevices.rawValue) private var showOfflineDevices: Bool = true
    
    @Binding var showMenuBarExtra: Bool
    @Binding var addDeviceButtonActive:Bool
    
    @ToolbarContentBuilder
    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .principal) {
            VStack {
                Image(.wledLogoAkemi)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            }
            .frame(maxWidth: 200)
        }
        #endif
        ToolbarItem {
            Menu {
                Section {
                    addButton
                }
                Section {
                    visibilityButton
                    hideOfflineButton
                    #if os(macOS)
                    showMenuBarButton
                    #endif
                }
                Section {
                    Link(destination: URL(string: "https://kno.wled.ge/")!) {
                        Label("WLED Documentation", systemImage: "questionmark.circle")
                    }
                }
            } label: {
                Label("Menu", systemImage: "ellipsis.circle")
            }
        }
    }
    
    var addButton: some View {
        Button {
            addDeviceButtonActive.toggle()
        } label: {
            Label("Add New Device", systemImage: "plus")
        }
    }
    
    var visibilityButton: some View {
        Button {
            withAnimation {
                showHiddenDevices.toggle()
            }
        } label: {
            if (showHiddenDevices) {
                Label("Hide Hidden Devices", systemImage: "eye.slash")
            } else {
                Label("Show Hidden Devices", systemImage: "eye")
            }
        }
    }
    
    var hideOfflineButton: some View {
        Button {
            withAnimation {
                showOfflineDevices.toggle()
            }
        } label: {
            if (showOfflineDevices) {
                Label("Hide Offline Devices", systemImage: "wifi")
            } else {
                Label("Show Offline Devices", systemImage: "wifi.slash")
            }
        }
    }
    
    var showMenuBarButton: some View {
        Button {
            showMenuBarExtra.toggle()
        } label: {
            if (showMenuBarExtra) {
                Label("Hide from Menu Bar", systemImage: "eye.slash")
            } else {
                Label("Show in Menu Bar", systemImage: "eye")
            }
        }
    }
}
