import Testing
import Foundation
import CoreData
import Combine
@testable import WLED

@MainActor
struct DeviceWebsocketListViewModelTests {

    let container: NSPersistentContainer
    let context: NSManagedObjectContext

    init() {
        self.container = PersistenceController.preview.container
        self.context = container.viewContext
        
        // Clear existing data from preview
        let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
        if let devices = try? context.fetch(fetchRequest) {
            for device in devices {
                context.delete(device)
            }
        }
        try? context.save()
    }

    @Test func testInitialLoadingAndSorting() async throws {
        // 1. Setup mock data
        let device1 = createDevice(name: "Z Device", mac: "01", isHidden: false)
        let device2 = createDevice(name: "A Device", mac: "02", isHidden: false)
        let device3 = createDevice(name: "Hidden Device", mac: "03", isHidden: true)
        try context.save()

        let viewModel = DeviceWebsocketListViewModel(context: context)
        viewModel.makeClient = { device in MockWebsocketClient(device: device) }
        
        // 2. Load — filtering now happens synchronously
        viewModel.load()
        
        #expect(viewModel.allDevicesWithState.count == 3)
        
        // Hidden devices should be excluded by default
        viewModel.showHiddenDevices = false
        viewModel.updateFilteredDevices(currentTime: Date())
        
        let allNames = (viewModel.onlineDevices + viewModel.offlineDevices).map { $0.device.displayName }
        #expect(allNames.contains("A Device"))
        #expect(allNames.contains("Z Device"))
        #expect(!allNames.contains("Hidden Device"))
    }

    @Test func testReactivityToStatusChange() async throws {
        let device = createDevice(name: "Test Device", mac: "01", isHidden: false)
        try context.save()

        let viewModel = DeviceWebsocketListViewModel(context: context)
        let mockClient = ManualMockWebsocketClient(device: device)
        viewModel.makeClient = { _ in mockClient }
        
        viewModel.load()
        
        // Initially disconnected
        mockClient.setStatus(.disconnected)
        viewModel.updateFilteredDevices(currentTime: Date())
        
        #expect(viewModel.offlineDevices.count == 1)
        #expect(viewModel.onlineDevices.isEmpty)

        // Switch to connected — the reactive pipeline triggers immediately (no debounce)
        mockClient.setStatus(.connected)
        try await Task.sleep(for: .milliseconds(100)) // Brief yield for Combine pipeline
        
        #expect(viewModel.onlineDevices.count == 1)
        #expect(viewModel.offlineDevices.isEmpty)
    }

    // MARK: - Helpers

    private func createDevice(name: String, mac: String, isHidden: Bool) -> Device {
        let device = Device(context: context)
        device.address = "192.168.1.\(mac)" // Required field
        device.macAddress = mac
        device.originalName = name
        device.isHidden = isHidden
        return device
    }
}

// Precise control mock
class ManualMockWebsocketClient: WebsocketClient {
    func setStatus(_ status: WebsocketStatus) {
        self.deviceState.websocketStatus = status
    }
    
    override func connect() { /* no-op */ }
    override func disconnect() { /* no-op */ }
}
