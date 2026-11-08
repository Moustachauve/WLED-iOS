import SwiftUI

/// Two horizontal pages: the device list (left) and the selected device's controls (right).
/// Swiping right from the controls goes back to the list.
struct DeviceListWatchView: View {
    @Environment(WatchDeviceStore.self) private var store
    @AppStorage("lastDeviceID") private var lastDeviceID = ""
    @State private var page = Page.list
    @State private var didAutoOpen = false

    private enum Page { case list, control }

    private var selectedDevice: WatchDevice? {
        store.devices.first { $0.id == lastDeviceID }
    }

    var body: some View {
        TabView(selection: $page) {
            listPage.tag(Page.list)
            controlPage.tag(Page.control)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Reopen the last device at launch. The list may arrive after launch, so retry on changes.
        .onAppear(perform: openLastDevice)
        .onChange(of: store.devices) { openLastDevice() }
    }

    private func openLastDevice() {
        guard !didAutoOpen, selectedDevice != nil else { return }
        didAutoOpen = true
        page = .control
    }

    // MARK: - Pages

    private var listPage: some View {
        NavigationStack {
            Group {
                if store.devices.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.title2)
                        Text("No devices")
                            .font(.headline)
                        Text("Open WLED on your iPhone to sync your devices.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(store.devices) { device in
                        Button {
                            lastDeviceID = device.id
                            withAnimation { page = .control }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .lineLimit(1)
                                Text(device.address)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listItemTint(device.id == lastDeviceID ? .yellow.opacity(0.3) : nil)
                    }
                }
            }
            .navigationTitle("WLED")
        }
    }

    @ViewBuilder
    private var controlPage: some View {
        if let device = selectedDevice {
            NavigationStack {
                // `id` recreates the controller when another device is picked or its address changes.
                DeviceControlView(device: device, isActive: page == .control)
                    .id(device)
            }
        } else {
            Text("Select a device")
                .foregroundStyle(.secondary)
        }
    }
}
