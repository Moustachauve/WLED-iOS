//
//  PreviewData.swift
//  WLED
//
//  Created by Christophe Gagnier on 2025-12-27.
//

import Foundation
import SwiftUI
import CoreData

@MainActor
struct PreviewData {

    static var viewContext: NSManagedObjectContext {
        return PersistenceController.preview.container.viewContext
    }

    // MARK: - Devices

    static var onlineDevice: DeviceWithState {
        createDevice(name: "WLED Beam", ip: "10.0.1.12", version: "0.14.0")
    }

    static var offlineDevice: DeviceWithState {
        let device = createDevice(name: "WLED Strip", ip: "10.0.1.13", version: "0.14.0")
        device.websocketStatus = .disconnected
        // Set last seen to 2 hours ago
        device.device.lastSeen = Int64(Date().addingTimeInterval(-7200).timeIntervalSince1970 * 1000)
        return device
    }

    static var deviceWithUpdate: DeviceWithState {
        // Device is on 0.13.0, Update 0.14.0 is available in DB
        ensureVersionsExist()
        let device = createDevice(name: "Old WLED", ip: "10.0.1.14", version: "0.13.0")
        // Force the available update version for preview purposes since the Combine pipeline might be async
        device.availableUpdateVersion = "0.14.0"
        return device
    }

    static var hiddenDevice: DeviceWithState {
        let device = createDevice(name: "Hidden Light", ip: "10.0.1.15", version: "0.14.0")
        device.device.isHidden = true
        return device
    }

    // MARK: - Helpers

    private static func createDevice(name: String, ip: String, version: String) -> DeviceWithState {
        let device = Device(context: viewContext)
        device.macAddress = UUID().uuidString
        device.originalName = name
        device.address = ip
        device.isHidden = false

        let deviceWithState = DeviceWithState(initialDevice: device)
        deviceWithState.websocketStatus = .connected
        deviceWithState.stateInfo = .mock(name: name, version: version)
        return deviceWithState
    }

    private static func ensureVersionsExist() {
        // Create a mock update version in CoreData if needed
        // Assuming 'Version' entity exists and has 'tagName'
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Version")
        request.predicate = NSPredicate(format: "tagName == %@", "0.14.0")

        if let count = try? viewContext.count(for: request), count == 0 {
            let version = Version(context: viewContext)
            version.tagName = "0.14.0"
            version.name = "v0.14.0 Hoshi"
            version.versionDescription = "## What's Changed\n\n* Cool new features by @Aircoookie"
            version.isPrerelease = false
            version.publishedDate = Date()
            try? viewContext.save()
        }
    }
}

// MARK: - Mock Data Extensions

extension DeviceStateInfo {
    static func mock(name: String, version: String) -> DeviceStateInfo {
        let json = """
        {
            "state": {
                "on": true,
                "bri": 128,
                "seg": [
                    {"id": 0, "col": [[255, 160, 0], [0, 0, 0], [0, 0, 0]]}
                ]
            },
            "info": {
                "name": "\(name)",
                "ver": "\(version)",
                "leds": { "count": 30, "pwr": 0, "fps": 0, "maxpwr": 0, "maxseg": 0 },
                "wifi": { "signal": -60 }
            }
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(DeviceStateInfo.self, from: data)
    }
}
