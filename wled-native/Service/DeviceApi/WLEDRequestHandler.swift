
import Foundation

protocol WLEDRequestHandler: Sendable {
    func processRequest(_ request: WLEDRequest) async
}
