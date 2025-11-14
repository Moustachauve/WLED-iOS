
import Foundation
import CoreData

struct WLEDSoftwareUpdateRequest: WLEDRequest {
    let context: NSManagedObjectContext
    let binaryFile: URL
    let onCompletion: () -> ()
    let onFailure: () -> ()
}
