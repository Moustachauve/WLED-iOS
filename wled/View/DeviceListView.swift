
import SwiftUI
import CoreData


struct DeviceListView: View {

    // MARK: - Properties
    @StateObject private var viewModel: DeviceWebsocketListViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: DeviceWithState? = nil
    @State private var addDeviceButtonActive: Bool = false
    @State private var currentTime = Date()

    @SceneStorage("DeviceListView.showHiddenDevices") private var showHiddenDevices: Bool = false
    @SceneStorage("DeviceListView.showOfflineDevices") private var showOfflineDevices: Bool = true

    /// Amount of time after a device becomes offline before it is considered offline.
    private let offlineGracePeriod: TimeInterval = 60
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // MARK: - init

    // Allow injecting a specific context (defaulting to shared for the actual app)
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        _viewModel = StateObject(wrappedValue: DeviceWebsocketListViewModel(context: context))
    }

    // MARK: - Computed Data

    /// Determines if a device should be displayed in the "Online" section.
    /// Returns true if the device is connected OR if it was seen within the grace period.
    private func isConsideredOnline(_ device: DeviceWithState, at referenceTime: Date) -> Bool {
        if device.isOnline { return true }

        // Calculate time since last seen
        // lastSeen is Int64 (milliseconds), convert to TimeInterval (seconds)
        let lastSeenSeconds = TimeInterval(device.device.lastSeen) / 1000.0
        let lastSeenDate = Date(timeIntervalSince1970: lastSeenSeconds)

        // Check if within grace period
        return Date().timeIntervalSince(lastSeenDate) < offlineGracePeriod
    }

    private var onlineDevices: [DeviceWithState] {
        viewModel.allDevicesWithState.filter { device in
            isConsideredOnline(device, at: currentTime) && (showHiddenDevices || !device.device.isHidden)
        }
        .sorted { $0.device.displayName.localizedStandardCompare($1.device.displayName) == .orderedAscending }
    }

    private var offlineDevices: [DeviceWithState] {
        viewModel.allDevicesWithState.filter { device in
            !isConsideredOnline(device, at: currentTime) && (showHiddenDevices || !device.device.isHidden)
        }
        .sorted { $0.device.displayName.localizedStandardCompare($1.device.displayName) == .orderedAscending }
    }

    //MARK: - Body

    var body: some View {
        NavigationSplitView {
            list
                .toolbar{ toolbar }
                .sheet(isPresented: $addDeviceButtonActive) {
                    DeviceAddView()
                        .presentationBackground(.thinMaterial)
                }
                .navigationBarTitleDisplayMode(.inline)
        } detail: {
            detailView
        }
        .onAppear(perform: appearAction)
        .onReceive(timer) { input in
            withAnimation {
                // Updating this state variable forces 'onlineDevices' to be re-evaluated
                currentTime = input
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                viewModel.onResume()
                currentTime = Date()
            case .background, .inactive:
                viewModel.onPause()
            @unknown default:
                break
            }
        }
    }
    
    var list: some View {
        List(selection: $selection) {
            if !onlineDevices.isEmpty {
                deviceRows(for: onlineDevices)
            } else if !showOfflineDevices && offlineDevices.isEmpty {
                // Empty state hint could go here
            }

            // Offline Devices
            if !offlineDevices.isEmpty && showOfflineDevices {
                Section(header: Text("Offline Devices")) {
                    deviceRows(for: offlineDevices)
                }
            }
        }
        .listStyle(.plain)
        .refreshable(action: refreshList)
        .navigationTitle("Device List")
    }

    @ViewBuilder
    private func deviceRows(for devices: [DeviceWithState]) -> some View {
        ForEach(devices) { device in
            DeviceListItemView(
                device: device,
                onTogglePower: { isOn in
                    viewModel.setDevicePower(for: device, isOn: isOn)
                },
                onChangeBrightness: { brightness in
                    viewModel.setBrightness(for: device, brightness: brightness)
                }
            )
            .overlay(
                // Invisible NavigationLink to handle selection while preserving custom row interactions
                NavigationLink("", value: device).opacity(0)
            )
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .buttonStyle(PlainButtonStyle())
            .swipeActions(allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteItems(device: device.device)
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            }
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let device = selection {
            NavigationStack {
                DeviceView(device: device)
            }
        } else {
            Text("Select A Device")
                .font(.title2)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack {
                Image(.wledLogoAkemi)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            }
            .frame(maxWidth: 200)
        }
        ToolbarItem {
            Menu {
                Section {
                    addButton
                }
                Section {
                    visibilityButton
                    hideOfflineButton
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
    
    //MARK: - Actions
    
    @Sendable
    private func refreshList() async {
        viewModel.startDiscovery()
        viewModel.refreshOfflineDevices()
    }

    private func appearAction() {
        viewModel.load()
        viewModel.onResume()
        viewModel.startDiscovery()
    }
    
    private func deleteItems(device: Device) {
        withAnimation {
            viewModel.deleteDevice(device)
        }
    }
}


#Preview {
    // Ensure some data exists in the preview context
    let _ = PreviewData.onlineDevice
    let _ = PreviewData.offlineDevice
    
    DeviceListView(context: PreviewData.viewContext)
}
