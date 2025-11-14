
import Foundation
import CoreData

struct WLEDChangeStateRequest: WLEDRequest {
    let state: WLEDStateChange
    let context: NSManagedObjectContext
}
