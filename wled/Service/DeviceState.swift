
import Foundation

// Stores transient information about a device
class DeviceState {
    private var requestManager: WLEDRequestManager?
    
    func getRequestManager(device: Device) -> WLEDRequestManager {
        if (requestManager == nil) {
            requestManager = WLEDRequestManager(device: device)
        }
        return requestManager!
    }
}
