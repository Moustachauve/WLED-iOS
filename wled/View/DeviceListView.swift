
import SwiftUI
import CoreData

struct DeviceListView: View {

    // MARK: - Properties
    @StateObject private var viewModel: DeviceWebsocketListViewModel

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: DeviceWithState? = nil

    @State private var addDeviceButtonActive: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var currentTime = Date()

    @AppStorage("DeviceListView.showHiddenDevices") private var showHiddenDevices: Bool = false
    @AppStorage("DeviceListView.showOfflineDevices") private var showOfflineDevices: Bool = true
    @AppStorage("lastSelectedDeviceMac") private var lastSelectedDeviceMac: String = ""

    /// Amount of time after a device becomes offline before it is considered offline.
    private let offlineGracePeriod: TimeInterval = 60
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var hasHiddenDevices: Bool {
        viewModel.allDevicesWithState.contains { $0.device.isHidden }
    }

    // MARK: - init

    // Allow injecting a specific context (defaulting to shared for the actual app)
    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        clientFactory: ((Device) -> WebsocketClient)? = nil
    ) {
        let viewModel = DeviceWebsocketListViewModel(context: context)
        if let clientFactory = clientFactory {
            viewModel.makeClient = clientFactory
        }
        _viewModel = StateObject(wrappedValue: viewModel)
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
                }
                .sheet(isPresented: $showSettingsSheet) {
                    Settings(
                        showHiddenDevices: $showHiddenDevices,
                        showOfflineDevices: $showOfflineDevices
                    )
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
        .onChange(of: viewModel.allDevicesWithState) { devices in
            restoreLastSelection(from: devices)
        }
        .onChange(of: selection) { newSelection in
            if let mac = newSelection?.device.macAddress {
                lastSelectedDeviceMac = mac
            }
        }
        // Listen for layout changes (e.g. iPad rotation or window resizing)
        // If the user expands the window, we want to fill the empty space immediately.
        .onChange(of: horizontalSizeClass) { newSizeClass in
            print(
                "changed horizontalSizeClass, \(horizontalSizeClass, default: "unknown") -> \(newSizeClass, default: "unknown")"
            )
            // newSizeClass needs to be passed because the actual sizeClass is
            // not changed just yet.
            restoreLastSelection(
                from: viewModel.allDevicesWithState,
                currentSizeClass: newSizeClass
            )
        }
    }

    var list: some View {
        ZStack {
            List(selection: $selection) {
                if !onlineDevices.isEmpty {
                    deviceRows(for: onlineDevices)
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
            
            
            if onlineDevices.isEmpty && offlineDevices.isEmpty {
                EmptyDeviceListView(
                    addDeviceButtonActive: $addDeviceButtonActive,
                    showHiddenDevices: $showHiddenDevices,
                    hasHiddenDevices: hasHiddenDevices
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: showHiddenDevices)
        .navigationTitle("Device List")
    }
        

    @ViewBuilder
    private func deviceRows(for devices: [DeviceWithState]) -> some View {
        ForEach(devices) { device in
            DeviceListItemView(
                device: device,
                isSelected: selection == device,
                onTogglePower: { isOn in
                    viewModel.setDevicePower(for: device, isOn: isOn)
                },
                onChangeBrightness: { brightness in
                    viewModel.setBrightness(for: device, brightness: brightness)
                }
            )
            .onTapGesture {
                withAnimation {
                    selection = device
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .buttonStyle(.plain)
            .swipeActions(allowsFullSwipe: true) {
                Button(role: .destructive) {
                    withAnimation {
                        deleteItems(device: device.device)
                        let remainingDevices = devices.filter { $0 != device }
                        // Call restore in case the selected item was deleted, this
                        // will select another device (most likely the first one)
                        restoreLastSelection(from: remainingDevices)
                    }
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
            Image(.wledLogoAkemi)
                .resizable()
                .scaledToFit()
                .padding(3)
                .frame(height: 50)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            // 1. Add Button (Direct Access)
            Button {
                addDeviceButtonActive.toggle()
            } label: {
                Label("Add Device", systemImage: "plus")
            }

            // 2. Settings Button
            Button {
                showSettingsSheet.toggle()
            } label: {
                Label("Settings", systemImage: "ellipsis.circle")
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
        if (selection?.device == device) {
            selection = nil
        }
        viewModel.deleteDevice(device)
    }

    // MARK: - Automatic device selection

    private func restoreLastSelection(
        from devices: [DeviceWithState],
        currentSizeClass: UserInterfaceSizeClass? = nil
    ) {
        // Use the passed-in class if available, otherwise use the environment value
        let sizeClass = currentSizeClass ?? horizontalSizeClass
        // Only run if we are in a wide layout (Split View is active)
        // This prevents auto-navigation on iPhone or iPad narrow multitasking.
        guard sizeClass == .regular else { return }
        // IMPORTANT: Only try to restore if NOTHING is currently selected.
        // This prevents us from overriding a device the user just clicked on,
        // while ensuring we fill the "empty" screen if it appears.
        guard selection == nil else { return }
        // Ensure there are devices to select
        guard !devices.isEmpty else { return }

        // Try to find the last selected device by MAC address
        if let lastDevice = devices.first(where: { $0.device.macAddress == lastSelectedDeviceMac }) {
            selection = lastDevice
        }
        // Fallback: Auto-select the first device
        else if let firstDevice = devices.first {
            selection = firstDevice
        }
    }
}

#Preview {
    // Ensure some data exists in the preview context
    let _ = PreviewData.onlineDevice
    let _ = PreviewData.offlineDevice
    let _ = PreviewData.deviceWithUpdate
    let _ = PreviewData.hiddenDevice

    DeviceListView(
        context: PreviewData.viewContext,
        clientFactory: { device in
            MockWebsocketClient(device: device)
        }
    )
    .environment(\.managedObjectContext, PreviewData.viewContext)
}
