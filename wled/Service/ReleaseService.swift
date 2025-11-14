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
     * @param branch Which branch to check for the update
     * @param ignoreVersion You can specify a version tag to be ignored as a new version. If this is
     *      set and match with the newest version, no version will be returned
     * @return The newest version if it is newer than versionName and different than ignoreVersion,
     *      otherwise an empty string.
     */
    func getNewerReleaseTag(versionName: String, branch: Branch, ignoreVersion: String) -> String {
        if (versionName.isEmpty) {
            return ""
        }
        let latestVersion = getLatestVersion(branch: branch)
        guard let latestTagName = latestVersion?.tagName, latestTagName != ignoreVersion else {
            return ""
        }
        
        // If device is currently on a beta branch but the user selected a stable branch,
        // show the latest version as an update so that the user can get out of beta.
        if (branch == .stable && versionName.contains("-b")) {
            return latestTagName
        }

        let versionCompare = latestTagName.dropFirst().compare(versionName, options: .numeric)
        return versionCompare == .orderedDescending ? latestTagName : ""
    }
        
        
    func getLatestVersion(branch: Branch) -> Version? {
        let fetchRequest = Version.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "publishedDate", ascending: false)]
        
        if (branch == Branch.stable) {
            fetchRequest.predicate = NSPredicate(format: "isPrerelease == %@", "0")
        }
        
        do {
            let versions = try context.fetch(fetchRequest)
            return versions.first
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    
    func refreshVersions() async {
        let allReleases = await WLEDRepoApi().getAllReleases()
        
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
    
   
    
    private func createVersion(release: Release) -> Version {
        let version = Version(context: context)
        version.tagName = release.tagName
        version.name = release.name
        version.versionDescription = release.body
        version.isPrerelease = release.prerelease
        version.htmlUrl = release.htmlUrl
        
        let dateFormatter = ISO8601DateFormatter()
        version.publishedDate = dateFormatter.date(from: release.publishedAt)
        
        return version
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
