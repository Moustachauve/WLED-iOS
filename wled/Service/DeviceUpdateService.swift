import Foundation
import CoreData

class DeviceUpdateService {
    let device: Device
    let version: Version
    let context: NSManagedObjectContext
    
    private(set) var couldDetermineAsset = false
    private var asset: Asset? = nil
    var githubApi: GithubApi?
    
    var supportedPlatforms: [String] {
        get {
            return [
                "esp01",
                "esp02",
                "esp32",
                "esp8266",
            ]
        }
    }
    
    init(device: Device, version: Version, context: NSManagedObjectContext) {
        self.device = device
        self.version = version
        self.context = context
    }
    
    func getGithubApi() -> GithubApi {
        if let githubApi = self.githubApi {
            return githubApi
        }
        let newApi = WLEDRepoApi()
        self.githubApi = newApi
        return newApi
    }
    
    func getVersionWithPlatformName() -> String {
        let ethernetVariant = device.isEthernet ? "_Ethernet" : ""
        var versionTagName = version.tagName ?? "v0"
        versionTagName.remove(at: versionTagName.startIndex)
        return "WLED_\(versionTagName)_\(device.platformName?.uppercased() ?? "")\(ethernetVariant).bin"
    }
    
    func determineAsset() {
        guard supportedPlatforms.contains(device.platformName ?? "") else {
            return
        }
        guard let assets = version.assets else {
            return
        }
        
        let assetName = getVersionWithPlatformName()
        for assetObject in assets {
            if let asset = assetObject as? Asset {
                if asset.name != assetName {
                    continue;
                }
                self.asset = asset
                couldDetermineAsset = true
                return
            }
        }
    }
    
    func getVersionAsset() -> Asset? {
        return asset
    }
    
    func isAssetFileCached() -> Bool {
        guard let binaryPath = getPathForAsset() else {
            return false
        }
        return FileManager.default.fileExists(atPath: binaryPath.path)
    }
    
    func getRequest(url: URL) -> URLRequest {
        return URLRequest(url: url)
    }
    
    func downloadBinary() async -> Bool {
        guard let asset = asset else {
            return false
        }
        guard let localUrl = getPathForAsset() else {
            return false
        }
        
        return await getGithubApi().downloadReleaseBinary(asset: asset, targetFile: localUrl)
    }
    
    func installUpdate(onCompletion: @escaping () -> (), onFailure: @escaping () -> ()) {
        guard let binaryPath = getPathForAsset() else {
            onFailure()
            return
        }
        Task {
            await device.requestManager.addRequest(WLEDSoftwareUpdateRequest(
                context: context,
                binaryFile: binaryPath,
                onCompletion: onCompletion,
                onFailure: onFailure
            ))
        }
    }
    
    func getPathForAsset() -> URL? {
        guard let cacheUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = cacheUrl.appendingPathComponent(version.tagName ?? "unknown", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathExtension(asset?.name ?? "unknown")
        } catch (let writeError) {
            print("error creating directory \(directory) : \(writeError)")
            return nil
        }
    }
}
