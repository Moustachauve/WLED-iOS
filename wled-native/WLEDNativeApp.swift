
import SwiftUI

enum WindowIds: String {
    case main = "WLEDNativeApp-main"
}

enum WLED:String {
    case showHiddenDevices = "WLED.showHiddenDevices"
    case showOfflineDevices = "WLED.showOfflineDevices"
}

@main
struct WLEDNativeApp: App {
    
    
    @State private var showMenuBarExtra:Bool = true
    @State private var addDeviceButtonActive: Bool = false
    
    
    static let dateLastUpdateKey = "lastUpdateReleasesDate"
    
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        #if os(macOS)
        //  The Menu Bar for macOS
        MenuBarExtra(
            "WLED",
            systemImage: "lamp.table.fill",
            isInserted: $showMenuBarExtra
        ) {
            MenuBar()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .frame(height: 300)
        }
            .menuBarExtraStyle(.window)
        
        Window("WLED", id: WindowIds.main.rawValue) {
            DeviceListViewFabric.makeWindow()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear() {
                    refreshVersionsSync()
                }
                .sheet(isPresented: $addDeviceButtonActive, content: DeviceAddView.init)
                .toolbar{ Toolbar(
                    showMenuBarExtra: $showMenuBarExtra,
                    addDeviceButtonActive: $addDeviceButtonActive
                ) }
        }
        WindowGroup {}
        #elseif os(iOS)
        WindowGroup {
            DeviceListViewFabric.makeWindow()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear() {
                    refreshVersionsSync()
                }
                .sheet(isPresented: $addDeviceButtonActive, content: DeviceAddView.init)
                .toolbar{ Toolbar(
                    showMenuBarExtra: $showMenuBarExtra,
                    addDeviceButtonActive: $addDeviceButtonActive
                ) }
        }
        #endif
    }
    
    
    private func refreshVersionsSync() {
        Task {
            // Only update automatically from Github once per 24 hours to avoid rate limits
            // and reduce network usage.
            let date = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: WLEDNativeApp.dateLastUpdateKey))
            var dateComponent = DateComponents()
            dateComponent.day = 1
            let dateToRefresh = Calendar.current.date(byAdding: dateComponent, to: date)
            let dateNow = Date()
            guard let dateToRefresh = dateToRefresh else {
                return
            }
            if (dateNow <= dateToRefresh) {
                return
            }
            print("Refreshing available Releases")
            await ReleaseService(context: persistenceController.container.viewContext).refreshVersions()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: WLEDNativeApp.dateLastUpdateKey)
        }
    }
}
