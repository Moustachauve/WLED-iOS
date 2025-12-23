import Foundation
import SwiftUI
import Combine
import CoreData

// TODO: This probably shouldn't be in the Websocket folder?

let AP_MODE_MAC_ADDRESS = "00:00:00:00:00:00"

enum WebsocketStatus {
    case connected
    case connecting
    case disconnected
    
    func toString() -> String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        }
    }
}

@MainActor
class DeviceWithState: ObservableObject, Identifiable {
    private var cancellables = Set<AnyCancellable>()

    @Published var device: Device
    @Published var stateInfo: DeviceStateInfo? = nil
    @Published var websocketStatus: WebsocketStatus = .disconnected
    @Published var availableUpdateVersion: String? = nil

    nonisolated let id: String

    init(initialDevice: Device) {
        self.device = initialDevice
        self.id = initialDevice.macAddress ?? initialDevice.objectID.uriRepresentation().absoluteString

        setupUpdatePipeline()
        setDeviceWillChange()
    }

    private func setDeviceWillChange() {
        // Forward changes from the inner Core Data Device to this wrapper
        device.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Calculated properties

    var isOnline: Bool {
        return websocketStatus == .connected
    }
    
    var isAPMode: Bool {
        return device.macAddress == AP_MODE_MAC_ADDRESS
    }

    var hasUpdateAvailable: Bool {
        return !(availableUpdateVersion ?? "").isEmpty
    }

    // MARK: - Update pipeline code

    private func setupUpdatePipeline() {
        $device
            .map { device in
                // This defines which values in the device can cause a
                // recalculation of the currently available version.
                return Publishers.CombineLatest(
                    device.publisher(for: \.branch),
                    device.publisher(for: \.skipUpdateTag)
                )
                .map { (branch: $0, skipTag: $1, device: device) }
            }
            .switchToLatest()
            .combineLatest($stateInfo)
            .receive(on: DispatchQueue.main) // Perform logic on Main Thread (safe for Core Data)
            .map { [weak self] (deviceInputs, stateInfo) -> String? in
                guard let self = self else { return nil }
                //return "v0.15.2"
                let (branchRaw, skipTag, device) = deviceInputs

                // Extract necessary info, fail fast if missing
                guard let info = stateInfo?.info,
                      let currentVersion = info.version,
                      let context = device.managedObjectContext else {
                    return nil
                }

                // Use your existing Service logic
                // Note: We use the raw strings from Core Data to create the Enum
                let branchEnum = Branch(rawValue: branchRaw ?? "") ?? .unknown

                let releaseService = ReleaseService(context: context)
                let newerTag = releaseService.getNewerReleaseTag(
                    versionName: currentVersion,
                    branch: branchEnum,
                    ignoreVersion: skipTag ?? ""
                )

                return newerTag.isEmpty ? nil : newerTag
            }
            .removeDuplicates()
            .assign(to: &$availableUpdateVersion)
    }

    // MARK: - Helper Functions

    /**
     * Get a DeviceWithState that can be used to represent a temporary WLED device in AP mode.
     * Note: Since Device is a Core Data entity, we need a context to create it.
     */
    static func getApModeDeviceWithState(context: NSManagedObjectContext) -> DeviceWithState {
        // Create a new Device entity
        // We assume this is transient and might not be saved to the persistent store immediately
        let device = Device(context: context)
        device.macAddress = AP_MODE_MAC_ADDRESS
        device.address = "4.3.2.1"

        let deviceWithState = DeviceWithState(initialDevice: device)
        deviceWithState.websocketStatus = .connected

        return deviceWithState
    }

}

// MARK: - Hashable & Equatable Conformance
extension DeviceWithState: Hashable {
    // Two instances are equal if they are the exact same object in memory
    nonisolated static func == (lhs: DeviceWithState, rhs: DeviceWithState) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hash based on the object's unique memory address
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
