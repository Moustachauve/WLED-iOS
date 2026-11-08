import Foundation
import Observation
import os

/// Talks to one WLED device over its HTTP JSON API (`/json/state`).
///
/// While the control screen is visible the state is polled every couple of seconds (`poll()`).
/// Local changes are applied optimistically and sent right away, in order; polled values for the
/// same field are ignored for a short while so the UI doesn't jump back.
@MainActor
@Observable
final class DeviceController {
    enum Connection {
        case connecting, online, offline
    }

    /// 0 means the strip is off (WLED treats `bri: 0` as off).
    static let minBrightness: Double = 0
    static let maxBrightness: Double = 255

    let device: WatchDevice

    private(set) var connection: Connection = .connecting
    private(set) var isOn = false
    private(set) var isNightlightOn = false
    /// When the active nightlight finishes. `nil` if inactive or unknown.
    private(set) var nightlightEnd: Date?
    /// Shown brightness. While on: the device's current brightness. While off: the brightness
    /// it will have once turned on. Dragging it to 0 turns the strip off. Change it with `setBrightness(_:)`.
    private(set) var brightness: Double = 128

    /// Last non-zero brightness known, restored when the strip is turned back on.
    @ObservationIgnored private var lastBrightness: Double = 128
    /// Brightness to bring back when the nightlight ends. The nightlight fades the device's
    /// `bri` down, which must not overwrite the brightness the user picked.
    @ObservationIgnored private var preNightlightBrightness: Double?
    @ObservationIgnored private var brightnessSendTask: Task<Void, Never>?
    /// Tail of the chain of outgoing requests: each one waits for the previous, so they stay in order.
    @ObservationIgnored private var sendTask: Task<Void, Never>?
    @ObservationIgnored private var ignoreRemoteUntil: [Field: Date] = [:]

    private enum Field { case power, brightness, nightlight }

    private let pollInterval: Duration = .seconds(2)
    private let localChangeGrace: TimeInterval = 2
    private let session: URLSession
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WLEDWatch", category: "DeviceController")

    init(device: WatchDevice) {
        self.device = device
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    deinit {
        session.invalidateAndCancel()
    }

    // MARK: - Lifecycle

    /// Polls the device until the calling task is cancelled. Run it from `.task`.
    func poll() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: pollInterval)
        }
    }

    // MARK: - Commands

    func setPower(_ on: Bool) {
        isOn = on
        markLocalChange(.power)
        send(DeviceStateUpdate(on: on))
    }

    func setNightlight(_ on: Bool) {
        let wasOn = isNightlightOn
        isNightlightOn = on
        if !on { nightlightEnd = nil }
        markLocalChange(.nightlight)
        if on, !wasOn { preNightlightBrightness = lastBrightness }
        // Nightlight only makes sense with the strip on. Duration and mode are the ones
        // configured on the device (set up from the iPhone / WLED settings).
        var update = DeviceStateUpdate(nl: .init(on: on))
        if on {
            isOn = true
            if brightness == 0 { brightness = lastBrightness }
            update.on = true
        } else if wasOn, let saved = preNightlightBrightness {
            // Stopping the nightlight leaves the device at its faded brightness: put it back.
            preNightlightBrightness = nil
            lastBrightness = saved
            if isOn { brightness = saved }
            update.bri = Int(saved.rounded())
            markLocalChange(.brightness)
        }
        send(update)
    }

    /// Sets the brightness chosen by the user. 0 turns the strip off.
    func setBrightness(_ value: Double) {
        guard value != brightness else { return }
        brightness = value
        markLocalChange(.brightness)
        markLocalChange(.power)
        let level = Int(value.rounded())
        isOn = level > 0
        if level > 0 {
            lastBrightness = value
            // Changed by hand during a nightlight: that's the value to restore afterwards.
            if preNightlightBrightness != nil { preNightlightBrightness = value }
        }
        brightnessSendTask?.cancel()
        brightnessSendTask = Task { [weak self] in
            // Debounce: the crown produces many values per second.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            // 0 = off. Don't send `bri: 0`, so the device keeps its brightness for next power on.
            self?.send(level == 0 ? DeviceStateUpdate(on: false) : DeviceStateUpdate(on: true, bri: level))
        }
    }

    // MARK: - Networking

    private var stateURL: URL? {
        URL(string: "http://\(device.address)/json/state")
    }

    private func refresh() async {
        guard let url = stateURL else { return }
        do {
            let (data, _) = try await session.data(from: url)
            apply(try JSONDecoder().decode(WledState.self, from: data))
        } catch {
            guard !Task.isCancelled else { return }
            Self.log.error("Poll failed for \(self.device.address, privacy: .public): \(error)")
            connection = .offline
        }
    }

    private func send(_ update: DeviceStateUpdate) {
        guard let url = stateURL else { return }
        let body: Data
        do {
            body = try JSONEncoder().encode(update)
        } catch {
            Self.log.error("Could not encode state update: \(error)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let session = session
        let previous = sendTask
        sendTask = Task { [weak self] in
            await previous?.value
            do {
                let (responseData, _) = try await session.data(for: request)
                do {
                    self?.apply(try JSONDecoder().decode(WledState.self, from: responseData))
                } catch {
                    // The command went through, only the echo of the new state is unreadable.
                    Self.log.error("Could not decode state response: \(error)")
                    self?.connection = .online
                }
            } catch {
                Self.log.error("Send failed: \(error)")
                self?.connection = .offline
            }
        }
    }

    // MARK: - State

    private func markLocalChange(_ field: Field) {
        ignoreRemoteUntil[field] = Date.now.addingTimeInterval(localChangeGrace)
    }

    private func shouldApplyRemote(_ field: Field) -> Bool {
        guard let until = ignoreRemoteUntil[field] else { return true }
        return Date.now >= until
    }

    private func apply(_ state: WledState) {
        connection = .online

        let applyPower = shouldApplyRemote(.power)
        let nightlightNow = state.nightlight?.isOn ?? false
        let nightlightWasOn = isNightlightOn
        if applyPower, let on = state.isOn {
            isOn = on
        }
        // While a nightlight runs (or just ended), `bri` is the faded value: don't remember it.
        if !nightlightNow, !nightlightWasOn, let bri = state.brightness, bri > 0 {
            lastBrightness = min(Double(bri), Self.maxBrightness)
        }
        if shouldApplyRemote(.nightlight), let nl = state.nightlight {
            isNightlightOn = nightlightNow
            if isNightlightOn, let remaining = nl.remainingTime, remaining >= 0 {
                nightlightEnd = Date.now.addingTimeInterval(TimeInterval(remaining))
            } else {
                nightlightEnd = nil
            }
            if nightlightNow, !nightlightWasOn, preNightlightBrightness == nil {
                // Started elsewhere (iPhone, WLED UI, schedule).
                preNightlightBrightness = lastBrightness
            } else if !nightlightNow, nightlightWasOn {
                restoreBrightnessAfterNightlight()
            }
        }
        if applyPower, shouldApplyRemote(.brightness) {
            // On: the live brightness of the device. Off: the brightness it will have when turned on.
            if isOn, let bri = state.brightness, bri > 0 {
                brightness = min(Double(bri), Self.maxBrightness)
            } else {
                brightness = lastBrightness
            }
        }
    }

    /// The nightlight finished by itself (or was stopped elsewhere): put the user's brightness back.
    private func restoreBrightnessAfterNightlight() {
        guard let saved = preNightlightBrightness else { return }
        preNightlightBrightness = nil
        lastBrightness = saved
        markLocalChange(.brightness)
        // If the nightlight turned the strip off, keep it off. Setting `on: false` also stores
        // the brightness on the device for the next power on.
        send(DeviceStateUpdate(on: isOn ? nil : false, bri: Int(saved.rounded())))
    }
}
