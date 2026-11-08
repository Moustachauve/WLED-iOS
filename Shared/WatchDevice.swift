import Foundation

/// Minimal description of a WLED device, sent from the iPhone to the Apple Watch.
///
/// Device configuration (names, discovery, firmware updates...) stays on the iPhone.
/// The watch only receives what it needs to reach a device and control it.
struct WatchDevice: Codable, Identifiable, Hashable, Sendable {
    /// MAC address, stable across IP changes.
    let id: String
    let name: String
    let address: String
}
