
import Testing
import Foundation
@testable import WLED

struct UserModsDecodingTests {

    @Test func testDecodeUserMods() throws {
        let json = """
        {
            "u": {
                "Battery level": [85],
                "Battery voltage": [3.9]
            }
        }
        """.data(using: .utf8)!

        // We can't decode UserMods directly easily because it's part of Info which has many required fields.
        // However, we can create a wrapper struct just for testing decoding of UserMods,
        // or we can test decoding of UserMods itself if we conform it to Decodable (which it is).

        let decoder = JSONDecoder()

        struct TestContainer: Decodable {
            let u: UserMods
        }

        let result = try decoder.decode(TestContainer.self, from: json)

        #expect(result.u.batteryLevel == 85)
        #expect(result.u.batteryVoltage == 3.9)
    }

    @Test func testDecodeUserModsWithDoubleLevel() throws {
        let json = """
        {
            "u": {
                "Battery level": [85.5],
                "Battery voltage": [3.9]
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()

        struct TestContainer: Decodable {
            let u: UserMods
        }

        let result = try decoder.decode(TestContainer.self, from: json)

        #expect(result.u.batteryLevel == 85) // casted to Int
        #expect(result.u.batteryVoltage == 3.9)
    }

    @Test func testDecodeUserModsMissingData() throws {
        let json = """
        {
            "u": {}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()

        struct TestContainer: Decodable {
            let u: UserMods
        }

        let result = try decoder.decode(TestContainer.self, from: json)

        #expect(result.u.batteryLevel == nil)
        #expect(result.u.batteryVoltage == nil)
    }
}
