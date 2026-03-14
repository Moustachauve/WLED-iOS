
import SwiftUI

@main
struct WLEDNativeApp: App {
    static let dateLastUpdateKey = "lastUpdateReleasesDate"
    
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            DeviceListView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear() {
                    refreshVersionsSync()
                }
        }
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

            // Collect all unique repositories used by known devices so we fetch
            // releases from the correct GitHub repo for each device.
            // Always include the default WLED repository to support pre-0.15.2 devices
            // that don't report a repo field.
            let context = persistenceController.container.viewContext
            let repositories: Set<String> = await context.perform {
                let request: NSFetchRequest<Device> = Device.fetchRequest()
                let devices = (try? context.fetch(request)) ?? []
                var repos = Set<String>([GithubApi.defaultRepository])
                for device in devices {
                    if let repository = device.repository, !repository.isEmpty {
                        repos.insert(repository)
                    }
                }
                return repos
            }

            let releaseService = ReleaseService(context: context)
            for repository in repositories {
                await releaseService.refreshVersions(repository: repository)
            }

            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: WLEDNativeApp.dateLastUpdateKey)
        }
    }
}
