import Foundation
@testable import WLEDWatch

/// In-memory WLED device, used as the `HTTPTransport` of a `DeviceController`.
///
/// Answers `GET` and `POST /json/state` like the firmware does (with the full state),
/// and records every update it receives.
final class FakeWledDevice: HTTPTransport, @unchecked Sendable {
    struct State {
        var on = false
        var bri = 128
        var nightlightOn = false
        var nightlightRemaining = -1
    }

    /// Body of a `POST` received by the device.
    struct Update: Decodable, Equatable {
        struct Nightlight: Decodable, Equatable {
            let on: Bool
        }

        var on: Bool?
        var bri: Int?
        var nl: Nightlight?
    }

    let watchDevice = WatchDevice(id: "AA:BB:CC:DD:EE:FF", name: "Fake", address: "192.168.1.50")

    private let lock = NSLock()
    private var _state: State
    private var _updates: [Update] = []
    private var _isReachable = true
    private var _sendsGarbage = false
    private var _isInvalidated = false
    private var _requestsAfterInvalidate = 0

    init(_ state: State = State()) {
        _state = state
    }

    /// Current state. Set it to simulate a change made elsewhere (iPhone, WLED UI, nightlight fade...).
    var state: State {
        get { lock.withLock { _state } }
        set { lock.withLock { _state = newValue } }
    }

    /// Every `POST` body received, in order.
    var updates: [Update] {
        lock.withLock { _updates }
    }

    /// When `false`, every request fails with a network error.
    var isReachable: Bool {
        get { lock.withLock { _isReachable } }
        set { lock.withLock { _isReachable = newValue } }
    }

    /// When `true`, responses are not valid JSON (but requests are still handled).
    var sendsGarbage: Bool {
        get { lock.withLock { _sendsGarbage } }
        set { lock.withLock { _sendsGarbage = newValue } }
    }

    /// Whether `invalidate()` was called.
    var isInvalidated: Bool {
        lock.withLock { _isInvalidated }
    }

    /// Requests received after `invalidate()`. A real `URLSession` raises an exception for those.
    var requestsAfterInvalidate: Int {
        lock.withLock { _requestsAfterInvalidate }
    }

    // MARK: - HTTPTransport

    func data(for request: URLRequest) async throws -> Data {
        try lock.withLock {
            if _isInvalidated {
                _requestsAfterInvalidate += 1
                throw URLError(.cancelled)
            }
            guard request.url?.path == "/json/state" else { throw URLError(.fileDoesNotExist) }
            guard _isReachable else { throw URLError(.cannotConnectToHost) }
            if request.httpMethod == "POST" {
                let update = try JSONDecoder().decode(Update.self, from: request.httpBody ?? Data())
                _updates.append(update)
                if let on = update.on { _state.on = on }
                if let bri = update.bri { _state.bri = bri }
                if let nl = update.nl {
                    _state.nightlightOn = nl.on
                    _state.nightlightRemaining = nl.on ? 600 : -1
                }
            }
            if _sendsGarbage { return Data("not json".utf8) }
            return Self.json(for: _state)
        }
    }

    func invalidate() {
        lock.withLock { _isInvalidated = true }
    }

    private static func json(for state: State) -> Data {
        let nightlight: [String: Any] = [
            "on": state.nightlightOn, "dur": 10, "mode": 1, "tbri": 0, "rem": state.nightlightRemaining
        ]
        let object: [String: Any] = ["on": state.on, "bri": state.bri, "nl": nightlight]
        // swiftlint:disable:next force_try
        return try! JSONSerialization.data(withJSONObject: object)
    }
}
