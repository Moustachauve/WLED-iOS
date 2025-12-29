
import SwiftUI
import CoreData

// TODO: Improve first load UX on tablet, it shows "Select A Device" with
// nothing else. Maybe it should auto-select the first device? or save the last
// selected device in SceneStorage or something.

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

    /// Amount of time after a device becomes offline before it is considered offline.
    private let offlineGracePeriod: TimeInterval = 60
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

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
                isSelected: selection == device,
                onTogglePower: { isOn in
                    viewModel.setDevicePower(for: device, isOn: isOn)
                },
                onChangeBrightness: { brightness in
                    viewModel.setBrightness(for: device, brightness: brightness)
                }
            )
            .background(
                Group {
                    if horizontalSizeClass == .compact {
                        // iPhone: Use a real NavigationLink to trigger the "Push" animation.
                        // We link directly to DeviceView since we are bypassing the split-view selection logic.
                        NavigationLink(destination: DeviceView(device: device)) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    // iPad: No NavigationLink (prevents blue ring/system styling).
                }
            )
            .onTapGesture {
                // Both: Update the selection state.
                // On iPad: This is the ONLY trigger for the detail view.
                // On iPhone: This runs simultaneously with the NavigationLink to keep state in sync.
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
                    deleteItems(device: device.device)
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            }
        }
        .accentColor(.clear)
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
        withAnimation {
            viewModel.deleteDevice(device)
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
