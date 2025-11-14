
import Foundation

class DeviceStateFactory {
    static var shared = DeviceStateFactory()
    
    private let dispatchQueue = DispatchQueue(label: "deviceStateFactory", attributes: .concurrent)
    private var allDeviceStates: Dictionary<String, DeviceState> = [:]
    
    func getStateForDevice(_ device: Device) -> DeviceState {
        let address = device.address ?? "unknown"
        var deviceState: DeviceState?
        dispatchQueue.sync(flags: .barrier) {
            if !self.allDeviceStates.keys.contains(address) {
                self.allDeviceStates[address] = DeviceState()
            }
            
            deviceState = self.allDeviceStates[address]!
        }
        return deviceState!
    }
}
