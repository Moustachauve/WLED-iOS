import XCTest
import CoreData
@testable import WLED

class StatelessDeviceMigrationPolicyTests: XCTestCase {

    var sourceModel: NSManagedObjectModel!
    var destinationModel: NSManagedObjectModel!

    override func setUp() {
        super.setUp()
        sourceModel = createSourceModel()
        destinationModel = createDestinationModel()
    }

    override func tearDown() {
        sourceModel = nil
        destinationModel = nil
        super.tearDown()
    }

    func testValidMigration() {
        let policy = StatelessDeviceMigrationPolicy()
        let manager = MockMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        let mapping = NSEntityMapping()

        let sourceContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        sourceContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)

        // Create valid source object
        let sourceEntity = sourceModel.entitiesByName["Device"]!
        let sInstance = NSManagedObject(entity: sourceEntity, insertInto: sourceContext)
        sInstance.setValue("00:11:22:33:44:55", forKey: "macAddress")
        sInstance.setValue("192.168.1.100", forKey: "address")
        sInstance.setValue(false, forKey: "isCustomName")
        sInstance.setValue("My Light", forKey: "name")
        sInstance.setValue(true, forKey: "isHidden")
        sInstance.setValue("v1.0", forKey: "skipUpdateTag")

        do {
            try policy.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

            XCTAssertEqual(manager.createdDestinations.count, 1)
            let dInstance = manager.createdDestinations.first!

            XCTAssertEqual(dInstance.value(forKey: "macAddress") as? String, "00:11:22:33:44:55")
            XCTAssertEqual(dInstance.value(forKey: "address") as? String, "192.168.1.100")
            XCTAssertEqual(dInstance.value(forKey: "isHidden") as? Bool, true)
            XCTAssertEqual(dInstance.value(forKey: "skipUpdateTag") as? String, "v1.0")

            // Verify Name Logic for non-custom name
            XCTAssertNil(dInstance.value(forKey: "customName"))
            XCTAssertEqual(dInstance.value(forKey: "originalName") as? String, "My Light")

            // Verify Defaults
            XCTAssertEqual(dInstance.value(forKey: "branch") as? String, "unknown") // Branch.unknown.rawValue
            XCTAssertEqual(dInstance.value(forKey: "lastSeen") as? Int, 0)

            // Verify Association
            XCTAssertTrue(manager.associateCalled)

        } catch {
            XCTFail("Migration failed with error: \(error)")
        }
    }

    func testValidMigrationWithCustomName() {
        let policy = StatelessDeviceMigrationPolicy()
        let manager = MockMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        let mapping = NSEntityMapping()

        let sourceContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        sourceContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)

        // Create valid source object with custom name
        let sourceEntity = sourceModel.entitiesByName["Device"]!
        let sInstance = NSManagedObject(entity: sourceEntity, insertInto: sourceContext)
        sInstance.setValue("AA:BB:CC:DD:EE:FF", forKey: "macAddress")
        sInstance.setValue(true, forKey: "isCustomName")
        sInstance.setValue("Custom Light", forKey: "name")

        do {
            try policy.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

            XCTAssertEqual(manager.createdDestinations.count, 1)
            let dInstance = manager.createdDestinations.first!

            // Verify Name Logic for custom name
            XCTAssertEqual(dInstance.value(forKey: "customName") as? String, "Custom Light")
            XCTAssertNil(dInstance.value(forKey: "originalName"))

        } catch {
            XCTFail("Migration failed with error: \(error)")
        }
    }

    func testEmptyMacAddress() {
        let policy = StatelessDeviceMigrationPolicy()
        let manager = MockMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        let mapping = NSEntityMapping()

        let sourceContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        sourceContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)

        let sInstance = NSManagedObject(entity: sourceModel.entitiesByName["Device"]!, insertInto: sourceContext)
        sInstance.setValue("", forKey: "macAddress")

        do {
            try policy.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
            XCTAssertEqual(manager.createdDestinations.count, 0)
        } catch {
            XCTFail("Migration failed with error: \(error)")
        }
    }

    func testUnknownMacAddress() {
        let policy = StatelessDeviceMigrationPolicy()
        let manager = MockMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        let mapping = NSEntityMapping()

        let sourceContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        sourceContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)

        let sInstance = NSManagedObject(entity: sourceModel.entitiesByName["Device"]!, insertInto: sourceContext)
        sInstance.setValue("__unknown__", forKey: "macAddress")

        do {
            try policy.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
            XCTAssertEqual(manager.createdDestinations.count, 0)
        } catch {
            XCTFail("Migration failed with error: \(error)")
        }
    }

    func testMissingMacAddress() {
         let policy = StatelessDeviceMigrationPolicy()
         let manager = MockMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
         let mapping = NSEntityMapping()

         let sourceContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
         sourceContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)

         let sInstance = NSManagedObject(entity: sourceModel.entitiesByName["Device"]!, insertInto: sourceContext)
         sInstance.setValue(nil, forKey: "macAddress")

         do {
             try policy.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
             XCTAssertEqual(manager.createdDestinations.count, 0)
         } catch {
             XCTFail("Migration failed with error: \(error)")
         }
     }

    func testDuplicateMacAddress() {
        let policy = StatelessDeviceMigrationPolicy()
        let manager = MockMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        let mapping = NSEntityMapping()

        let sourceContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        sourceContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)

        let mac = "00:11:22:33:44:55"

        // First Object
        let sInstance1 = NSManagedObject(entity: sourceModel.entitiesByName["Device"]!, insertInto: sourceContext)
        sInstance1.setValue(mac, forKey: "macAddress")
        sInstance1.setValue("Name 1", forKey: "name")

        // Second Object (Duplicate)
        let sInstance2 = NSManagedObject(entity: sourceModel.entitiesByName["Device"]!, insertInto: sourceContext)
        sInstance2.setValue(mac, forKey: "macAddress")
        sInstance2.setValue("Name 2", forKey: "name")

        do {
            // Migrate first instance
            try policy.createDestinationInstances(forSource: sInstance1, in: mapping, manager: manager)
            XCTAssertEqual(manager.createdDestinations.count, 1)

            // Migrate second instance
            try policy.createDestinationInstances(forSource: sInstance2, in: mapping, manager: manager)
            XCTAssertEqual(manager.createdDestinations.count, 1, "Should not create a second instance for duplicate MAC")

        } catch {
            XCTFail("Migration failed with error: \(error)")
        }
    }

    // MARK: - Helpers

    func createSourceModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Based on wled_native_data.xcdatamodel (the older one likely, or the one we are migrating FROM)
        // We assume the source has attributes we are reading from.
        let deviceEntity = NSEntityDescription()
        deviceEntity.name = "Device"
        deviceEntity.managedObjectClassName = "NSManagedObject" // Use generic for test

        let macAttr = NSAttributeDescription()
        macAttr.name = "macAddress"
        macAttr.attributeType = .stringAttributeType
        macAttr.isOptional = true

        let addrAttr = NSAttributeDescription()
        addrAttr.name = "address"
        addrAttr.attributeType = .stringAttributeType

        let isCustomNameAttr = NSAttributeDescription()
        isCustomNameAttr.name = "isCustomName"
        isCustomNameAttr.attributeType = .booleanAttributeType

        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType

        let isHiddenAttr = NSAttributeDescription()
        isHiddenAttr.name = "isHidden"
        isHiddenAttr.attributeType = .booleanAttributeType

        let skipAttr = NSAttributeDescription()
        skipAttr.name = "skipUpdateTag"
        skipAttr.attributeType = .stringAttributeType

        deviceEntity.properties = [macAttr, addrAttr, isCustomNameAttr, nameAttr, isHiddenAttr, skipAttr]
        model.entities = [deviceEntity]

        return model
    }

    func createDestinationModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Based on v2.xcdatamodel (The target of migration)
        let deviceEntity = NSEntityDescription()
        deviceEntity.name = "Device"
        deviceEntity.managedObjectClassName = "NSManagedObject"

        let macAttr = NSAttributeDescription()
        macAttr.name = "macAddress"
        macAttr.attributeType = .stringAttributeType

        let addrAttr = NSAttributeDescription()
        addrAttr.name = "address"
        addrAttr.attributeType = .stringAttributeType

        let customNameAttr = NSAttributeDescription()
        customNameAttr.name = "customName"
        customNameAttr.attributeType = .stringAttributeType

        let originalNameAttr = NSAttributeDescription()
        originalNameAttr.name = "originalName"
        originalNameAttr.attributeType = .stringAttributeType

        let isHiddenAttr = NSAttributeDescription()
        isHiddenAttr.name = "isHidden"
        isHiddenAttr.attributeType = .booleanAttributeType

        let skipAttr = NSAttributeDescription()
        skipAttr.name = "skipUpdateTag"
        skipAttr.attributeType = .stringAttributeType

        let branchAttr = NSAttributeDescription()
        branchAttr.name = "branch"
        branchAttr.attributeType = .stringAttributeType

        let lastSeenAttr = NSAttributeDescription()
        lastSeenAttr.name = "lastSeen"
        lastSeenAttr.attributeType = .integer64AttributeType

        deviceEntity.properties = [macAttr, addrAttr, customNameAttr, originalNameAttr, isHiddenAttr, skipAttr, branchAttr, lastSeenAttr]
        model.entities = [deviceEntity]

        return model
    }
}

class MockMigrationManager: NSMigrationManager {
    var associateCalled = false
    var createdDestinations: [NSManagedObject] {
        // Find inserted objects in destination context
        // Since we are not saving, we look at registeredObjects or just rely on what we put in.
        // Actually, NSEntityDescription.insertNewObject puts it into the context.
        return _destinationContext.insertedObjects.map { $0 }
    }

    // We need a context that works.
    private let _destinationContext: NSManagedObjectContext

    override var destinationContext: NSManagedObjectContext {
        return _destinationContext
    }

    override init(sourceModel: NSManagedObjectModel, destinationModel: NSManagedObjectModel) {
        let psc = NSPersistentStoreCoordinator(managedObjectModel: destinationModel)
        do {
            try psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        } catch {
            print("Failed to add in-memory store: \(error)")
        }
        _destinationContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        _destinationContext.persistentStoreCoordinator = psc
        super.init(sourceModel: sourceModel, destinationModel: destinationModel)
    }

    override func associate(sourceInstance: NSManagedObject, withDestinationInstance destinationInstance: NSManagedObject, for mapping: NSEntityMapping) {
        associateCalled = true
    }
}
