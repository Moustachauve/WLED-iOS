import Foundation
import CoreData
import Combine
import WatchConnectivity
import os

/// Pushes the list of known WLED devices to the paired Apple Watch.
///
/// The watch is a remote control only: it never edits the device list. Whenever the
/// Core Data devices change (added, renamed, new IP...), the list is re-sent through
/// `WCSession.updateApplicationContext`, which always delivers the latest value.
@MainActor
final class WatchSyncService: NSObject {
    static let shared = WatchSyncService()

    private var context: NSManagedObjectContext?
    private var cancellable: AnyCancellable?
    private var lastSentData: Data?
    /// Latest encoded list, readable from WCSession's delegate queue to answer the watch's requests.
    private nonisolated let latestData = OSAllocatedUnfairLock<Data?>(initialState: nil)

    private nonisolated static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "wled", category: "WatchSyncService")
    /// Device attributes that end up in the list sent to the watch. Other changes (brightness,
    /// online state...) happen all the time and don't need a re-send.
    private nonisolated static let relevantKeys: Set<String> = ["customName", "originalName", "address", "macAddress", "isHidden"]

    func start(context: NSManagedObjectContext) {
        guard WCSession.isSupported(), self.context == nil else { return }
        self.context = context

        cancellable = NotificationCenter.default
            .publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .filter(Self.affectsWatchList)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pushDevices()
            }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private nonisolated static func affectsWatchList(_ notification: Notification) -> Bool {
        let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        if inserted.contains(where: { $0 is Device }) || deleted.contains(where: { $0 is Device }) {
            return true
        }
        return updated.contains { object in
            object is Device && !relevantKeys.isDisjoint(with: object.changedValues().keys)
        }
    }

    private func currentDevices() -> [WatchDevice] {
        guard let context else { return [] }
        let request = Device.fetchRequest()
        let devices: [Device]
        do {
            devices = try context.fetch(request)
        } catch {
            Self.log.error("Could not fetch devices: \(error)")
            return []
        }
        return devices
            .compactMap { device -> WatchDevice? in
                guard !device.isHidden,
                      let mac = device.macAddress, mac != AP_MODE_MAC_ADDRESS,
                      let address = device.address, !address.isEmpty
                else { return nil }
                return WatchDevice(id: mac, name: device.displayName, address: address)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func pushDevices() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        do {
            let data = try WatchSync.encode(currentDevices())
            latestData.withLock { $0 = data }
            guard data != lastSentData else { return }
            try session.updateApplicationContext([WatchSync.devicesKey: data])
            lastSentData = data
        } catch {
            Self.log.error("Failed to update application context: \(error)")
        }
    }
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.pushDevices()
        }
    }

    /// The watch asks for the list when it launches and missed the application context.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[WatchSync.requestKey] != nil else {
            replyHandler([:])
            return
        }
        // Reply right away with the last list pushed (kept up to date by `pushDevices`), so no
        // actor hop is needed. Empty data means "nothing to send yet": the watch ignores it.
        replyHandler([WatchSync.devicesKey: latestData.withLock { $0 } ?? Data()])
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Happens when switching to another paired watch.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        // The watch app may have just been installed: send the list right away.
        Task { @MainActor in
            self.lastSentData = nil
            self.pushDevices()
        }
    }
}
