import Foundation

/// Sends HTTP requests to a device. Replaced by a fake in tests.
protocol HTTPTransport: Sendable {
    /// Returns the body of the response.
    func data(for request: URLRequest) async throws -> Data
    /// Cancels the requests in flight. No request may be sent afterwards.
    func invalidate()
}

/// `HTTPTransport` backed by an ephemeral `URLSession` with short timeouts: devices are on
/// the local network, waiting longer only delays the "offline" state.
final class URLSessionTransport: HTTPTransport {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    func data(for request: URLRequest) async throws -> Data {
        try await session.data(for: request).0
    }

    func invalidate() {
        session.invalidateAndCancel()
    }
}
