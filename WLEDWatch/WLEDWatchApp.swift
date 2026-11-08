import SwiftUI

@main
struct WLEDWatchApp: App {
    @State private var store = WatchDeviceStore()

    var body: some Scene {
        WindowGroup {
            DeviceListWatchView()
                .environment(store)
        }
    }
}
