import Foundation
import CoreData

class IllumidelUpdateService: DeviceUpdateService {
    
    override var supportedPlatforms: [String] {
        get {
            return [
                "esp32",
            ]
        }
    }
    
    override init(device: Device, version: Version, context: NSManagedObjectContext) {
        super.init(device: device, version: version, context: context)
    }
    
    override func getGithubApi() -> GithubApi {
        if (githubApi == nil) {
            githubApi = IllumidelRepoApi()
        }
        return githubApi!
    }
    
    override func getVersionWithPlatformName() -> String {
        let langCode = device.branchValue == Branch.beta ? "en" : "fr"
        let versionTagName = version.tagName ?? "v0"
        return "\(versionTagName)_\(device.platformName?.uppercased() ?? "")_\(langCode).bin"
    }
    
    override func getRequest(url: URL) -> URLRequest {
        return IllumidelRepoApi().getRequest(url: url)
    }
}
