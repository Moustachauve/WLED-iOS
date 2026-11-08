import Foundation

/// Body of a `POST /json/state` request. Only the fields that are set are encoded.
struct DeviceStateUpdate: Encodable {
    struct Nightlight: Encodable {
        let on: Bool
    }

    var on: Bool?
    var bri: Int?
    var nl: Nightlight?
    /// Ask the device to answer with its full new state.
    var v = true
}
