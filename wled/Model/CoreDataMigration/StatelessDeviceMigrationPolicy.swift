import CoreData

class StatelessDeviceMigrationPolicy: NSEntityMigrationPolicy {
    
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        
        // 1. Filter out invalid MAC addresses
        guard let macAddress = sInstance.value(forKey: "macAddress") as? String,
              !macAddress.isEmpty,
              macAddress != "__unknown__" else {
            // If we return without creating a destination instance,
            // this item is effectively dropped/deleted during migration.
            return
        }
        
        // 2. Create the destination object (Device)
        let dInstance = NSEntityDescription.insertNewObject(forEntityName: "Device", into: manager.destinationContext)
        
        // 3. Copy direct mappings
        dInstance.setValue(macAddress, forKey: "macAddress")
        dInstance.setValue(sInstance.value(forKey: "address"), forKey: "address")
        dInstance.setValue(sInstance.value(forKey: "isHidden"), forKey: "isHidden")
        dInstance.setValue(sInstance.value(forKey: "skipUpdateTag"), forKey: "skipUpdateTag")
        
        // 4. Handle Name Logic
        let isCustomName = sInstance.value(forKey: "isCustomName") as? Bool ?? false
        let oldName = sInstance.value(forKey: "name") as? String ?? ""
        
        if isCustomName {
            dInstance.setValue(oldName, forKey: "customName")
            dInstance.setValue(nil, forKey: "originalName")
        } else {
            dInstance.setValue(nil, forKey: "customName")
            dInstance.setValue(oldName, forKey: "originalName")
        }
        
        // 5. Set Defaults
        dInstance.setValue("unknown", forKey: "branch")
        dInstance.setValue(0, forKey: "lastSeen")
        
        // 6. Associate the source and destination (Required)
        manager.associate(sourceInstance: sInstance, withDestinationInstance: dInstance, for: mapping)
    }
}
