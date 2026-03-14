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
     * @param repository The GitHub repository (owner/name) to check for updates.
     *      Defaults to the standard WLED repository.
     * @return The newest version if it is newer than versionName and different than ignoreVersion,
     *      otherwise an empty string.
     */
    func getNewerReleaseTag(versionName: String, branch: Branch, ignoreVersion: String, repository: String = GithubApi.defaultRepository) -> String {
        if (versionName.isEmpty) {
            return ""
        }
        let latestVersion = getLatestVersion(branch: branch, repository: repository)
        guard let latestTagName = latestVersion?.tagName, latestTagName != ignoreVersion else {
            return ""
        }

        // If device is currently on a beta branch but the user selected a stable branch,
        // show the latest version as an update so that the user can get out of beta.
        if (branch == .stable && versionName.contains("-b")) {
            return latestTagName
        }

        let versionCompare = latestTagName.compare(versionName, options: .numeric)
        return versionCompare == .orderedDescending ? latestTagName : ""
    }


    func getLatestVersion(branch: Branch, repository: String = GithubApi.defaultRepository) -> Version? {
        let fetchRequest = Version.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "publishedDate", ascending: false)]
        var predicates = [NSPredicate]()

        // For now, nightly branches are not supported.
        predicates.append(NSPredicate(format: "tagName != %@", "nightly"))

        if (branch == Branch.stable) {
            predicates.append(NSPredicate(format: "isPrerelease == %@", NSNumber(value: false)))
        }

        // Filter by repository, falling back to versions without a repository set
        // (e.g. versions that were cached before multi-repository support was added).
        // TODO: Once all users have migrated, this nil fallback can be removed.
        predicates.append(NSPredicate(
            format: "repository == %@ OR repository == nil",
            repository
        ))

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            let versions = try context.fetch(fetchRequest)
            return versions.first
        } catch {
            print("ReleaseService: Failed to fetch latest version. Error: \(error.localizedDescription)")
            return nil
        }
    }


    /// Fetches the latest releases for a given repository and refreshes them in Core Data.
    ///
    /// - Parameter repository: The GitHub repository (owner/name) to fetch releases for.
    ///   Defaults to the standard WLED repository.
    func refreshVersions(repository: String = GithubApi.defaultRepository) async {
        let allReleases = await GithubApi(repository: repository).getAllReleases()

        guard !allReleases.isEmpty else {
            print("Did not find any releases for \(repository)")
            return
        }

        // Capture context and repository locally to avoid capturing 'self' in the closure below
        let context = self.context
        let repoToRefresh = repository
        await context.perform {
            do {
                // Delete existing versions for this repository only.
                // The nil check handles any legacy versions cached before multi-repository
                // support was added — they are assumed to belong to the default repository.
                let fetchRequest = Version.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "repository == %@ OR repository == nil",
                    repoToRefresh
                )
                let versions = try context.fetch(fetchRequest)
                print("Deleting \(versions.count) versions for \(repoToRefresh)")
                for version in versions {
                    context.delete(version)
                }

                // Create new versions
                for release in allReleases {
                    let version = ReleaseService.createVersion(release: release, repository: repoToRefresh, context: context)
                    let assets = ReleaseService.createAssetsForVersion(version: version, release: release, context: context)
                    print("Added version \(version.tagName ?? "[unknown]") with \(assets.count) assets for \(repoToRefresh)")
                }

                try context.save()
            } catch {
                print("ReleaseService: Failed to refresh versions. Error: \(error.localizedDescription)")
                // Rollback to clear any invalid state from the context
                context.rollback()
            }
        }
    }

    // MARK: - Static Helpers
    // Made static to avoid capturing 'self' inside async/sendable closures
    
    private static func createVersion(release: Release, repository: String, context: NSManagedObjectContext) -> Version {
        let version = Version(context: context)
        // Strip 'v' prefix if present to normalize data with the WLED API
        if release.tagName.hasPrefix("v") {
            version.tagName = String(release.tagName.dropFirst())
        } else {
            version.tagName = release.tagName
        }
        version.name = release.name
        version.versionDescription = release.body
        version.isPrerelease = release.prerelease
        version.htmlUrl = release.htmlUrl
        version.repository = repository
        
        let dateFormatter = ISO8601DateFormatter()
        version.publishedDate = dateFormatter.date(from: release.publishedAt)
        
        return version
    }
    
    private static func createAssetsForVersion(version: Version, release: Release, context: NSManagedObjectContext) -> [Asset] {
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
