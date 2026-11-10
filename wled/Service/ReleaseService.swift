import Foundation
import CoreData

class ReleaseService {
    
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /**
     * If a new version is available, returns the version tag of it.
     *
     * @param versionName Current version to check if a newer one exists
     * @param ignoreVersion You can specify a version tag to be ignored as a new version. If this is
     *      set and match with the newest version, no version will be returned
     * @return The newest version if it is newer than versionName and different than ignoreVersion,
     *      otherwise an empty string.
     */
    func getNewerReleaseTag(versionName: String, ignoreVersion: String) -> String {
        let latestVersion = getLatestStableVersion()
        guard let latestTagName = latestVersion?.tagName, latestTagName != ignoreVersion else {
            return ""
        }
        
        return Self.isVersionNewer(releaseTag: latestTagName, than: versionName) ? latestTagName : ""
    }
    
    static func isVersionNewer(releaseTag: String, than currentVersion: String) -> Bool {
        guard !currentVersion.isEmpty, !releaseTag.isEmpty else {
            return false
        }
        let strippedReleaseTag = releaseTag.hasPrefix("v")
            ? String(releaseTag.dropFirst())
            : releaseTag
        return strippedReleaseTag.compare(currentVersion, options: .numeric) == .orderedDescending
    }
    
    
    func getLatestStableVersion() -> Version? {
        // Explicit `== nil` checks are required for optional Core Data attributes because
        // SQLite evaluates `NOT (NULL LIKE '%beta%')` as NULL (falsy) in a negated predicate.
        return fetchLatestVersion(
            predicate: NSPredicate(
                format: "isPrerelease == NO AND (versionDescription == nil OR NOT (versionDescription CONTAINS[cd] %@)) AND NOT (tagName CONTAINS[cd] %@) AND (name == nil OR NOT (name CONTAINS[cd] %@))",
                "beta", "beta", "beta"
            )
        )
    }
    
    func getLatestBetaVersion() -> Version? {
        return fetchLatestVersion(
            predicate: NSPredicate(
                format: "isPrerelease == YES OR versionDescription CONTAINS[cd] %@ OR tagName CONTAINS[cd] %@ OR name CONTAINS[cd] %@",
                "beta", "beta", "beta"
            )
        )
    }
    
    private func fetchLatestVersion(predicate: NSPredicate) -> Version? {
        let fetchRequest = Version.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "publishedDate", ascending: false)]
        fetchRequest.predicate = predicate
        
        do {
            let versions = try context.fetch(fetchRequest)
            return versions.first
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    func sanitizeDeviceUpdateTags() {
        context.performAndWait {
            let fetchRequest = Device.fetchRequest()
            guard let devices = try? context.fetch(fetchRequest) else {
                return
            }
            var hasChanges = false
            for device in devices {
                let currentUpdateTag = device.latestUpdateVersionTagAvailable ?? ""
                if !currentUpdateTag.isEmpty {
                    let validStableTag = getNewerReleaseTag(
                        versionName: device.version ?? "",
                        ignoreVersion: device.skipUpdateTag ?? ""
                    )
                    if validStableTag != currentUpdateTag {
                        device.latestUpdateVersionTagAvailable = validStableTag
                        hasChanges = true
                    }
                }
            }
            if hasChanges {
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
    
    
    func refreshVersions() async {
        let allReleases = await IllumidelRepoApi().getAllReleases()
        
        guard !allReleases.isEmpty else {
            print("Did not find any releases")
            return
        }
        
        context.performAndWait {
            // Delete existing versions first
            let fetchRequest = Version.fetchRequest()
            let versions = try? context.fetch(fetchRequest)
            print("Deleting \(versions?.count ?? 0) versions")
            for version in versions ?? [] {
                context.delete(version)
            }
            
            // Create new versions
            for release in allReleases {
                let version = createVersion(release: release)
                let assets = createAssetsForVersion(version: version, release: release)
                print("Added version \(version.tagName ?? "[unknown]") with \(assets.count) assets")
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
    
    
    
    func createVersion(release: Release) -> Version {
        let version = Version(context: context)
        version.tagName = release.tagName
        version.name = release.name
        version.versionDescription = release.body
        version.isPrerelease = isBetaRelease(release: release)
        version.htmlUrl = release.htmlUrl
        
        let dateFormatter = ISO8601DateFormatter()
        version.publishedDate = dateFormatter.date(from: release.publishedAt)
        
        return version
    }
    
    func isBetaRelease(release: Release) -> Bool {
        if release.prerelease {
            return true
        }
        let betaKeywords = ["beta", "bêta"]
        return betaKeywords.contains { keyword in
            release.tagName.localizedCaseInsensitiveContains(keyword) ||
                release.name.localizedCaseInsensitiveContains(keyword) ||
                release.body.localizedCaseInsensitiveContains(keyword)
        }
    }
    
    private func createAssetsForVersion(version: Version, release: Release) -> [Asset] {
        var assets = [Asset]()
        for releaseAsset in release.assets {
            let asset = Asset(context: context)
            asset.version = version
            asset.versionTagName = release.tagName
            asset.name = releaseAsset.name
            asset.size = releaseAsset.size
            asset.downloadUrl = releaseAsset.browserDownloadUrl
            asset.assetId = releaseAsset.id
            assets.append(asset)
        }
        return assets
    }
}
