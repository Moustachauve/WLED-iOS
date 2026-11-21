import Foundation
import Testing
@testable import WLEDWatch

@MainActor
struct WatchDeviceStoreTests {
    private let defaults: UserDefaults
    private let devices = [
        WatchDevice(id: "AA:BB:CC:DD:EE:FF", name: "Desk", address: "192.168.1.10"),
        WatchDevice(id: "11:22:33:44:55:66", name: "TV", address: "wled-tv.local")
    ]

    init() throws {
        let suiteName = "WatchDeviceStoreTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeStore() -> WatchDeviceStore {
        WatchDeviceStore(defaults: defaults, activateSession: false)
    }

    @Test func startsEmptyWithoutCache() {
        #expect(makeStore().devices.isEmpty)
    }

    @Test func receivedDevicesArePublishedAndCached() throws {
        let store = makeStore()

        store.apply(devicesData: try WatchSync.encode(devices))

        #expect(store.devices == devices)
        // A new store (next launch) starts from the cache.
        #expect(makeStore().devices == devices)
    }

    @Test func newListReplacesThePreviousOne() throws {
        let store = makeStore()
        store.apply(devicesData: try WatchSync.encode(devices))

        store.apply(devicesData: try WatchSync.encode([devices[1]]))

        #expect(store.devices == [devices[1]])
        #expect(makeStore().devices == [devices[1]])
    }

    @Test func emptyListClearsDevices() throws {
        let store = makeStore()
        store.apply(devicesData: try WatchSync.encode(devices))

        store.apply(devicesData: try WatchSync.encode([]))

        #expect(store.devices.isEmpty)
        #expect(makeStore().devices.isEmpty)
    }

    @Test func unreadableDataKeepsCurrentList() throws {
        let store = makeStore()
        store.apply(devicesData: try WatchSync.encode(devices))

        store.apply(devicesData: Data("nope".utf8))

        #expect(store.devices == devices)
        #expect(makeStore().devices == devices)
    }

    @Test func unreadableCacheIsIgnored() {
        defaults.set(Data("nope".utf8), forKey: "cachedDevices")
        #expect(makeStore().devices.isEmpty)
    }
}
