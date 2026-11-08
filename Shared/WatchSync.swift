import Foundation

/// Keys and coding shared by the iPhone and watch sides of the device sync.
enum WatchSync {
    /// Key of the `applicationContext` entry holding the JSON encoded `[WatchDevice]`.
    static let devicesKey = "devices"
    /// Key of the message the watch sends to ask the iPhone for the device list.
    static let requestKey = "requestDevices"

    static func encode(_ devices: [WatchDevice]) throws -> Data {
        try JSONEncoder().encode(devices)
    }

    static func decode(_ data: Data) throws -> [WatchDevice] {
        try JSONDecoder().decode([WatchDevice].self, from: data)
    }
}
