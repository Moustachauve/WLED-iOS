import Foundation
import CoreData

enum UpdateError: LocalizedError {
    case assetNotDetermined
    case fileNotFound
    case invalidURL
    case uploadFailed(Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .assetNotDetermined: return "Could not determine the correct firmware for this device."
        case .fileNotFound: return "Firmware file not found on disk."
        case .invalidURL: return "The device URL is invalid."
        case .uploadFailed(let code): return "Update failed with status code: \(code)"
        case .networkError(let error): return error.localizedDescription
        }
    }
}

/// Service responsible for identifying, downloading, and installing firmware updates for WLED devices.
@MainActor
class DeviceUpdateService : ObservableObject {

    // MARK: - Properties

    /// List of platforms supported by the legacy update method.
    let supportedPlatforms = [
        "esp01",
        "esp02",
        "esp32",
        "esp8266",
    ]

    let device: DeviceWithState
    let version: Version
    var githubApi: GithubApi?

    private var assetName: String = ""
    private(set) var couldDetermineAsset = false
    private var asset: Asset? = nil

    // MARK: - Initialization

    /// Initializes the update service and immediately attempts to determine the correct binary asset.
    ///
    /// - Parameters:
    ///   - device: The WLED device to update.
    ///   - version: The target firmware version.
    init(device: DeviceWithState, version: Version) {
        self.device = device
        self.version = version
        setupAsset()
    }

    private func setupAsset() {
        // Try to use the release variable, but fallback to the legacy platform method for
        // compatibility with WLED older than 0.15.0
        if !determineAssetByRelease() {
            determineAssetByPlatform()
        }
    }

    // MARK: - API Management

    /// Returns the existing GitHub API instance or creates a new one if it doesn't exist.
    ///
    /// - Returns: An instance of `GithubApi`.
    func getGithubApi() -> GithubApi {
        if let githubApi = self.githubApi {
            return githubApi
        }
        let newApi = WLEDRepoApi()
        self.githubApi = newApi
        return newApi
    }

    // MARK: - Asset Determination Strategies

    /// Determines the asset to download based on the `release` variable in the device info.
    ///
    /// This is the preferred method and is typically available on WLED devices running version 0.15.0 or newer.
    ///
    /// - Returns: `true` if the asset name was determined and found; otherwise `false`.
    private func determineAssetByRelease() -> Bool {
        guard let release = device.stateInfo?.info.release,
              !release.isEmpty,
              let tagName = version.tagName else {
            return false
        }

        let combined = "\(tagName)_\(release)"
        let versionWithRelease = combined.lowercased().hasPrefix("v")
        ? String(combined.dropFirst())
        : combined

        self.assetName = "WLED_\(versionWithRelease).bin"
        return findAsset(assetName: assetName)
    }

    /// Determines the asset to download based on the device platform (e.g., esp32).
    ///
    /// This is a legacy method used for backwards compatibility with WLED devices older than 0.15.0.
    private func determineAssetByPlatform() {
        guard let deviceInfo = device.stateInfo?.info,
              let platformName = deviceInfo.platformName,
              let tagName = version.tagName,
              supportedPlatforms.contains(platformName) else {
            return
        }
        let combined = "\(tagName)_\(platformName.uppercased())"

        let versionWithPlatform = combined.lowercased().hasPrefix("v") ? String(combined.dropFirst()) : combined
        self.assetName = "WLED_\(versionWithPlatform).bin"
        _ = findAsset(assetName: assetName)
    }

    /// Searches the `Version`'s assets for a specific filename.
    ///
    /// - Parameter assetName: The exact filename to look for (e.g., "WLED_0.14.0_ESP32.bin").
    /// - Returns: `true` if the asset was found, `false` otherwise.
    private func findAsset(assetName: String) -> Bool {
        if let foundAsset = (version.assets as? Set<Asset>)?.first(where: { $0.name == assetName}) {
            self.asset = foundAsset
            couldDetermineAsset = true
            return true
        }
        return false
    }

    func getAssetName() -> String {
        return assetName
    }

    // MARK: - Asset Management

    /// Retrieves the determined asset object, if any.
    ///
    /// - Returns: The `Asset` object or `nil` if not determined.
    func getVersionAsset() -> Asset? {
        return asset
    }

    /// Checks if the binary file for the determined asset is already saved locally.
    ///
    /// - Returns: `true` if the file exists on the disk, `false` otherwise.
    func isAssetFileCached() -> Bool {
        guard let binaryPath = getPathForAsset() else {
            return false
        }
        return FileManager.default.fileExists(atPath: binaryPath.path)
    }

    /// Downloads the firmware binary from GitHub and saves it to the local cache.
    ///
    /// - Returns: `true` if the download succeeded, `false` otherwise.
    func downloadBinary() async -> Bool {
        guard let asset = asset else {
            return false
        }
        guard let localUrl = getPathForAsset() else {
            return false
        }

        return await getGithubApi().downloadReleaseBinary(asset: asset, targetFile: localUrl)
    }

    // MARK: - File System Helpers

    /// Constructs the local file URL for where the asset should be stored.
    ///
    /// Structure: `.../Library/Caches/[tagName]/[assetName]`
    ///
    /// - Returns: The full `URL` to the file, or `nil` if the directory could not be created.
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

    // MARK: - Installation

    /// Initiates the firmware update process on the device using the downloaded binary.
    ///
    /// - Parameters:
    ///   - onCompletion: Closure called when the update completes successfully.
    ///   - onFailure: Closure called if the update fails or the binary cannot be found.
    func installUpdate() async throws {
        guard let binaryURL = getPathForAsset(),
              FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw UpdateError.fileNotFound
        }
        guard let deviceAddress = device.device.address,
              let url = URL(string: "http://\(deviceAddress)/update") else {
            throw UpdateError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Create the multipart wrapper (header + footer)
        // Note: For very large files, we should create a temporary file combining these,
        // but for WLED binaries (~1-2MB), streaming the file and appending works.
        let bodyData = try createMultipartBody(boundary: boundary, fileURL: binaryURL)

        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: bodyData)

            guard let httpResponse = response as? HTTPURLResponse else { throw UpdateError.networkError(NSError()) }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw UpdateError.uploadFailed(httpResponse.statusCode)
            }

            print("Update Success: \(String(decoding: data, as: UTF8.self))")
        } catch {
            throw UpdateError.networkError(error)
        }
    }

    private func createMultipartBody(boundary: String, fileURL: URL) throws -> Data {
        let fileName = "wled.bin"
        let mimeType = "application/octet-stream"

        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"update\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(try Data(contentsOf: fileURL)) // Still loads into RAM, see optimization note below
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        return data
    }
}
