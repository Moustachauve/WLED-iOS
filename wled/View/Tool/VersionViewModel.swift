import Foundation
import CoreData

class VersionViewModel: ObservableObject {

    @Published var version: Version?
    @Published var latestBetaVersion: Version?

    func loadVersion(_ versionTagParam: String, context: NSManagedObjectContext) {
        var versionTag = versionTagParam
        if !versionTag.isEmpty && !versionTag.hasPrefix("v") {
            versionTag = "v\(versionTag)"
        }
        let fetchRequest = Version.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tagName == %@ OR tagName == %@", versionTagParam, versionTag)

        do {
            print("loading new version...")
            version = try context.fetch(fetchRequest).first
            print("Done loading version: \(version?.tagName ?? "nil")")
        } catch {
            print("Unexpected error when loading version: \(error)")
        }
    }

    func loadLatestBetaVersion(context: NSManagedObjectContext) {
        latestBetaVersion = ReleaseService(context: context).getLatestBetaVersion()
    }
}
