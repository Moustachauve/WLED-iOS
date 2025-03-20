
import Foundation

struct WLEDSoftwareUpdateRequest: WLEDRequest {
    let binaryFile: URL
    let onCompletion: @MainActor () -> ()
    let onFailure: @MainActor () -> ()
}
