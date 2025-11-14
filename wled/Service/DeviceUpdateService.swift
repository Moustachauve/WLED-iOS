import Foundation
import CoreData

class DeviceUpdateService {
    
    let supportedPlatforms = [
        "esp01",
        "esp02",
        "esp32",
        "esp8266",
    ]
    
    let device: Device
    let version: Version
    let context: NSManagedObjectContext
    
    private(set) var couldDetermineAsset = false
    private var asset: Asset? = nil
    
    init(device: Device, version: Version, context: NSManagedObjectContext) {
        self.device = device
        self.version = version
        self.context = context
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
    
    func downloadBinary(onCompletion: @escaping (DeviceUpdateService) -> ()) {
        guard let assetUrl = URL(string: asset?.downloadUrl ?? "") else {
            // TODO: Handle errors
            return
        }
        guard let localUrl = getPathForAsset() else {
            // TODO: Handle errors
            return
        }

        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        let request = URLRequest(url: assetUrl)
        
        let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
            if let tempLocalUrl = tempLocalUrl, error == nil {
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    print("Success: \(statusCode)")
                }
                
                do {
                    try FileManager.default.copyItem(at: tempLocalUrl, to: localUrl)
                    onCompletion(self)
                } catch (let writeError) {
                    print("error writing file \(localUrl) : \(writeError)")
                }
                
            } else {
                print("Failure: \(error?.localizedDescription ?? "[Unknown]")");
            }
        }
        
        task.resume()
    }
    
    func installUpdate(onCompletion: @escaping () -> (), onFailure: @escaping () -> ()) {
        guard let binaryPath = getPathForAsset() else {
            // TODO: Handle errors
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
