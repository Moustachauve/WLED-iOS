
import Foundation

protocol WLEDRequestHandler {
    var device: Device { get }
    func processRequest(_ request: WLEDRequest) async
}
