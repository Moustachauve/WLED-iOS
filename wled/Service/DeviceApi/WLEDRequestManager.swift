
import Foundation
import Collections

actor WLEDRequestManager {
    let device: Device
    let requestHandler: WLEDRequestHandler
    var requestQueue: Deque<WLEDRequest> = []
    private var locked = false
    
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
            while (!requestQueue.isEmpty && canProcessMore) {
                print("Processing request")
                canProcessMore = await processRequests()
                print("Request done, processing next? \(canProcessMore)")
            }
        }
    }
    
    private func processRequests() async -> Bool {
        guard locked == false else {
            return false
        }
        locked = true
        defer {
            locked = false
        }
        guard let request = requestQueue.popFirst() else {
            return false
        }
        await requestHandler.processRequest(request)
        return true
    }
}
