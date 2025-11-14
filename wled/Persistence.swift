
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for i in 0..<10 {
            let newDevice = Device(context: viewContext)
            newDevice.tag = UUID()
            newDevice.name = i % 9 != 0 ? "Device \(i)" : ""
            newDevice.address = "192.168.1.\(i + 10)"
            newDevice.brightness = Int64(i * 26)
            newDevice.isOnline = i % 4 != 0
            newDevice.isPoweredOn = i % 2 != 0
            newDevice.isRefreshing = i % 8 == 0
            switch i % 3 {
            case 0:
                newDevice.networkRssi = -101
                newDevice.color = 38600
            case 1:
                newDevice.networkRssi = -90
                newDevice.color = 13107455
            case 2:
                newDevice.networkRssi = -70
                newDevice.color = 250255
            default:
                newDevice.networkRssi = -50
                newDevice.color = 1500
            }
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "wled_native_data")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }
}
