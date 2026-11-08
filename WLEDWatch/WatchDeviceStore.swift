import Foundation
import Observation
import WatchConnectivity
import os

/// Holds the list of devices received from the iPhone.
///
/// The list is cached in `UserDefaults` so devices are available right at launch,
/// even when the iPhone is out of reach.
@MainActor
@Observable
final class WatchDeviceStore: NSObject {
    private(set) var devices: [WatchDevice] = []

    @ObservationIgnored private static let cacheKey = "cachedDevices"
    private nonisolated static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WLEDWatch", category: "WatchDeviceStore")

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey) {
            do {
                devices = try WatchSync.decode(data)
            } catch {
                Self.log.error("Cached device list is unreadable: \(error)")
            }
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func apply(devicesData data: Data) {
        do {
            devices = try WatchSync.decode(data)
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        } catch {
            Self.log.error("Received device list is unreadable: \(error)")
        }
    }
}

extension WatchDeviceStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            Self.log.error("WCSession activation failed: \(error)")
        }
        // Pick up whatever the iPhone sent while the app was not running.
        if let data = session.receivedApplicationContext[WatchSync.devicesKey] as? Data {
            Task { @MainActor in
                self.apply(devicesData: data)
            }
        }
        // Also ask the iPhone directly, in case no context was ever delivered.
        requestDevices(session)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable { requestDevices(session) }
    }

    private nonisolated func requestDevices(_ session: WCSession) {
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([WatchSync.requestKey: true]) { reply in
            guard let data = reply[WatchSync.devicesKey] as? Data, !data.isEmpty else { return }
            Task { @MainActor in
                self.apply(devicesData: data)
            }
        } errorHandler: { error in
            Self.log.error("Device list request failed: \(error)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchSync.devicesKey] as? Data else { return }
        Task { @MainActor in
            self.apply(devicesData: data)
        }
    }
}
