
import Foundation

class WLEDWebsocketHandler : WLEDRequestHandler {
    var device: Device
    
    init(device: Device) {
        self.device = device
    }
    
    func processRequest(_ request: WLEDRequest) async {
        // TODO: Implement this
        fatalError("Not Implemented")
    }
    
    
}
