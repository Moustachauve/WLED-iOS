import Foundation

struct UserMods: Decodable {
    var batteryLevel: Int?
    var batteryVoltage: Double?

    enum CodingKeys: String, CodingKey {
        case batteryLevel = "Battery level"
        case batteryVoltage = "Battery voltage"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // The API returns arrays [85], [3.9]. We want the first element.
        // Battery level might be Int or Double.
        if let levelArray = try? container.decode([Int].self, forKey: .batteryLevel), let first = levelArray.first {
            batteryLevel = first
        } else if let levelArray = try? container.decode([Double].self, forKey: .batteryLevel), let first = levelArray.first {
            batteryLevel = Int(first)
        }

        if let voltageArray = try? container.decode([Double].self, forKey: .batteryVoltage), let first = voltageArray.first {
            batteryVoltage = first
        }
    }
}
