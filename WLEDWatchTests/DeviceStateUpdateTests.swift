import Foundation
import Testing
@testable import WLEDWatch

struct DeviceStateUpdateTests {
    private func encodedObject(_ update: DeviceStateUpdate) throws -> NSDictionary {
        let data = try JSONEncoder().encode(update)
        return try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    @Test func onlySetFieldsAreEncoded() throws {
        let object = try encodedObject(DeviceStateUpdate(on: true))
        #expect(object == ["on": true, "v": true])
    }

    @Test func brightnessAndNightlightAreEncoded() throws {
        let object = try encodedObject(DeviceStateUpdate(on: false, bri: 42, nl: .init(on: true)))
        #expect(object == ["on": false, "bri": 42, "nl": ["on": true], "v": true])
    }

    @Test func emptyUpdateStillAsksForState() throws {
        let object = try encodedObject(DeviceStateUpdate())
        #expect(object == ["v": true])
    }
}
