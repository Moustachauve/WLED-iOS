//
//  WLEDRequestManagerProvider.swift
//  wled-native
//
//  Created by Robert Brune on 07.10.24.
//

import Foundation

actor WLEDRequestManagerProvider {
    
    public static let shared = WLEDRequestManagerProvider()
    
    private var requestManagers: [Device: WLEDRequestManager] = [:]
    
    func getRequestManager(device: Device) -> WLEDRequestManager {
        requestManagers[device] ?? .init(device: device)
    }
}
