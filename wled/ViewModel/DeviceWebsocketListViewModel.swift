import Foundation
import CoreData
import Combine
import SwiftUI


@MainActor
class DeviceWebsocketListViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    
    // MARK: - Published Properties
    
    // The list of devices with their live state, exposed to the UI
    @Published var allDevicesWithState: [DeviceWithState] = []
    
    // Preferences (You can wrap these in AppStorage or standard UserDefaults in the View)
    @Published var showOfflineDevicesLast: Bool = false
    @Published var showHiddenDevices: Bool = false

    var makeClient: (Device) -> WebsocketClient = { device in
        WebsocketClient(device: device)
    }

    // MARK: - Private Properties

    private var discoveryService: DiscoveryService?
    private let deviceFirstContactService = DeviceFirstContactService()
    private let context: NSManagedObjectContext
    private var frc: NSFetchedResultsController<Device>!
    
    // Map of MacAddress -> Client Wrapper
    // We store the last known address to detect IP changes
    private struct ClientWrapper {
        let client: WebsocketClient
        let lastKnownAddress: String
    }
    
    private var activeClients: [String: ClientWrapper] = [:]
    private var isPaused = false
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()

        self.discoveryService = DiscoveryService{ [weak self] address, macAddress in
            Task { @MainActor [weak self] in
                self?.deviceDiscovered(at: address, withMACAddress: macAddress)
            }
        }

        // Load preferences (Mocked for now, replace with your UserPreferences logic)
        self.showOfflineDevicesLast = UserDefaults.standard.bool(forKey: "showOfflineDevicesLast")
        self.showHiddenDevices = UserDefaults.standard.bool(forKey: "showHiddenDevices")
    }

    // MARK: - Setup and loading

    /// Call this when the view appears to initialize data and connections
    func load() {
        // Prevent double loading if already set up
        guard frc == nil else { return }

        setupFetchedResultsController()

        // Initial population of clients
        try? frc.performFetch()
        if let objects = frc.fetchedObjects {
            updateClients(with: objects)
        }
    }

    // MARK: - Core Data Setup
    
    private func setupFetchedResultsController() {
        let request = NSFetchRequest<Device>(entityName: "Device")
        // Sort by lastSeen or name as a default
        request.sortDescriptors = [NSSortDescriptor(key: "lastSeen", ascending: false)]
        
        frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        frc.delegate = self
    }
    
    // MARK: - Client Management Logic
    
    private func updateClients(with devices: [Device]) {
        let newDeviceMap = Dictionary(uniqueKeysWithValues: devices.compactMap { device -> (String, Device)? in
            guard let mac = device.macAddress else { return nil }
            return (mac, device)
        })
        
        // 1. Identify and destroy clients for devices that are no longer present
        let currentMacs = Set(activeClients.keys)
        let newMacs = Set(newDeviceMap.keys)
        let macsToRemove = currentMacs.subtracting(newMacs)
        
        for mac in macsToRemove {
            print("[ListVM] Device removed: \(mac). Destroying client.")
            activeClients[mac]?.client.destroy()
            activeClients[mac] = nil
        }
        
        // 2. Identify and create/update clients for new or changed devices
        for (mac, device) in newDeviceMap {
            let address = device.address ?? ""
            
            if let existingWrapper = activeClients[mac] {
                if existingWrapper.lastKnownAddress != address {
                    // Address changed: Reconnect
                    print("[ListVM] Address changed for \(mac). Recreating client.")
                    existingWrapper.client.destroy()
                    createAndAddClient(for: device, mac: mac)
                } else {
                    // Just a regular update (e.g. name changed), the ObservableObject DeviceWithState handles this automatically
                    // because it holds the reference to the Core Data object.
                }
            } else {
                // New Device
                print("[ListVM] Device added: \(mac). Creating client.")
                createAndAddClient(for: device, mac: mac)
            }
        }
        
        publishState()
    }
    
    private func createAndAddClient(for device: Device, mac: String) {
        let newClient = makeClient(device)

        newClient.onDeviceStateUpdated = { [weak self] info in
            self?.handleDeviceUpdate(deviceID: device.objectID, info: info)
        }

        if !isPaused {
            newClient.connect()
        }
        
        activeClients[mac] = ClientWrapper(
            client: newClient,
            lastKnownAddress: device.address ?? ""
        )
    }

    private func handleDeviceUpdate(deviceID: NSManagedObjectID, info: DeviceStateInfo) {
        context.perform {
            guard let device = try? self.context.existingObject(with: deviceID) as? Device else { return }

            // Logic moved from WebsocketClient to here
            let newName = info.info.name
            let newVersion = info.info.version ?? ""

            // Flag to determine if we need an immediate disk write
            var structuralChange = false

            var currentBranch = device.branchValue
            if currentBranch == Branch.unknown {
                if newVersion.contains("-b") {
                    currentBranch = Branch.beta
                } else {
                    currentBranch = Branch.stable
                }
                device.branchValue = currentBranch
                structuralChange = true
            }
            if device.originalName != newName {
                device.originalName = newName
                structuralChange = true
            }

            // Update transient data (Updates UI in-memory, but no disk save needed yet)
            device.lastSeen = Int64(Date().timeIntervalSince1970 * 1000)

            // Only perform disk I/O if important data changed
            if structuralChange && self.context.hasChanges {
                try? self.context.save()
            }
        }
    }

    private func publishState() {
        // Map the clients to the DeviceWithState list expected by the UI
        DispatchQueue.main.async {
            self.allDevicesWithState = self.activeClients.values.map { wrapper in
                wrapper.client.deviceState
            }
        }
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        Task { @MainActor in
            guard let devices = self.frc.fetchedObjects else { return }
            self.updateClients(with: devices)
        }
    }

    // MARK: - Lifecycle (Call these from App ScenePhase)
    
    func onPause() {
        print("[ListVM] onPause: Pausing all connections.")
        isPaused = true
        activeClients.values.forEach { $0.client.disconnect() }
        
        // SAVE: Persist "lastSeen" and other pending changes when app goes to background
        if context.hasChanges {
            try? context.save()
        }
    }
    
    func onResume() {
        print("[ListVM] onResume: Resuming all connections.")
        isPaused = false
        activeClients.values.forEach { $0.client.connect() }
    }
    
    // MARK: - Actions
    
    func refreshOfflineDevices() {
        print("[ListVM] Refreshing offline devices.")
        let offlineClients = activeClients.values.filter { !$0.client.deviceState.isOnline }
        offlineClients.forEach { $0.client.connect() }
    }
    
    func setBrightness(for deviceWrapper: DeviceWithState, brightness: Int) {
        guard let mac = deviceWrapper.device.macAddress,
              let wrapper = activeClients[mac] else {
            print("[ListVM] No active client for \(deviceWrapper.device.macAddress ?? "nil")")
            return
        }
        deviceWrapper.stateInfo?.state.brightness = Int64(brightness)
        wrapper.client.sendState(WledState(brightness: Int64(brightness)))
    }
    
    func setDevicePower(for deviceWrapper: DeviceWithState, isOn: Bool) {
        guard let mac = deviceWrapper.device.macAddress,
              let wrapper = activeClients[mac] else {
            print("[ListVM] No active client for \(deviceWrapper.device.macAddress ?? "nil")")
            return
        }
        deviceWrapper.stateInfo?.state.isOn = isOn
        wrapper.client.sendState(WledState(isOn: isOn))
    }
    
    func deleteDevice(_ device: Device) {
        print("[ListVM] Deleting device \(device.originalName ?? "")")// Capture context locally to avoid isolation issues in the closure
        let objectID = device.objectID
        let ctx = context
        ctx.perform {
            if let deviceToDelete = try? ctx.existingObject(with: objectID) {
                ctx.delete(deviceToDelete)
                try? ctx.save()
            }
        }
    }

    // MARK: - Discovery Logic

    func startDiscovery() {
        print("[ListVM] Starting discovery scan")
        discoveryService?.scan()
    }

    private func deviceDiscovered(at address: String, withMACAddress macAddress: String?) {
        Task {
            do {
                if await !deviceFirstContactService
                    .tryUpdateAddress(macAddress: macAddress, address: address) {
                    _ = try await deviceFirstContactService
                        .fetchAndUpsertDevice(rawAddress: address)
                }
            } catch {
                print("deviceDiscovered: Failed to upsert device: \(error)")
            }
        }
    }
}
