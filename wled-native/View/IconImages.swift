//
//  IconImages.swift
//  wled-native
//
//  Created by Robert Brune on 20.03.25.
//

import SwiftUI

enum Icons {
    case update
    case wifi(isOnline: Bool, signalStrength: Int)
}

extension Icons: View {
    
    @ViewBuilder
    var body: some View {
        switch self {
        case .update: Image(systemName: getUpdateIconName())
        case .wifi(let isOnline, let signalStrength):
            getSignalImage(isOnline: isOnline, signalStrength: signalStrength)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.primary)
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 12)
        }
            
    }
    
    private func getUpdateIconName() -> String {
        if #available(iOS 17.0, *) {
            return "arrow.down.circle.dotted"
        } else {
            return "arrow.down.circle"
        }
    }
    
    
    func getSignalImage(isOnline: Bool, signalStrength: Int) -> Image {
        let icon = !isOnline || signalStrength == 0 ? "wifi.slash" : "wifi"
        if #available(iOS 16.0, *) {
            return Image(
                systemName: icon,
                variableValue: Double(signalStrength)
            )
        } else {
            return Image(
                systemName: icon
            )
        }
    }
    
    func getSignalValue(signalStrength: Int) -> Double {
        if (signalStrength >= -70) {
            return 1
        }
        if (signalStrength >= -85) {
            return 0.64
        }
        if (signalStrength >= -100) {
            return 0.33
        }
        return 0
    }
}
