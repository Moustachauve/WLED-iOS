
import Foundation

extension Device {
    var requestManager: WLEDRequestManager {
        get {
            return DeviceStateFactory.shared.getStateForDevice(self).getRequestManager(device: self)
        }
    }
    
    func getColor(state: WledState) -> Int64 {
        let colorInfo = state.segment?[0].colors?[0]
        let red = Int64(Double(colorInfo![0]) + 0.5)
        let green = Int64(Double(colorInfo![1]) + 0.5)
        let blue = Int64(Double(colorInfo![2]) + 0.5)
        return (red << 16) | (green << 8) | blue
    }
    
    func setStateValues(state: WledState) {
        isOnline = true
        brightness = state.brightness
        isPoweredOn = state.isOn
        isRefreshing = false
        color = getColor(state: state)
    }
}

extension Device: Observable { }
