
import Foundation
import Collections

//  A request manager manages serial access to a device to perform all updates sequentially
actor WLEDRequestManager {
    
    var device: Device
    
    let requestHandler: WLEDRequestHandler
    var requestQueue: Deque<WLEDRequest> = []
    
    init(device: Device) {
        self.device = device
        
        // TODO: Add websocket support
        requestHandler = WLEDJsonApiHandler(device: device)
    }
    
    func addRequest(_ request: WLEDRequest) {
        requestQueue.append(request)
        print("queuing request (#\(requestQueue.count))")
        processAllRequests()
    }
    
    func processAllRequests() {
        Task {
            var canProcessMore = true
            while (!self.requestQueue.isEmpty && canProcessMore) {
                print("Processing request")
                canProcessMore = await processRequests()
                print("Request done, processing next? \(canProcessMore)")
            }
        }
    }
    
    private func processRequests() async -> Bool {
        guard let request = requestQueue.popFirst() else {
            return false
        }
        await self.requestHandler.processRequest(request)
        return true
    }
}
