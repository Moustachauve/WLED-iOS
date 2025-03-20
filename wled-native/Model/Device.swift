//
//  Device.swift
//  wled-native
//
//  Created by Robert Brune on 20.03.25.
//

import Foundation
import SwiftUI

extension Device {
    
    
    var displayName: String {
        let emptyName = String(localized: "(New Device)")
        guard let name = self.name else {
            return emptyName
        }
        return name.isEmpty ? emptyName : name
    }
    
    var updateAvailable: Bool {
        return false
        /*
        self.managedObjectContext?.performAndWait {
            return !(self.latestUpdateVersionTagAvailable ?? "").isEmpty
        } ?? false
        */
    }
    
    func displayColor(colorScheme: ColorScheme) -> Color {
        colorFromHex(colorScheme: colorScheme)
    }
    
    func colorFromHex(colorScheme: ColorScheme) -> Color {
        // &  binary AND operator to zero out other color values
        // >>  bitwise right shift operator
        // Divide by 0xFF because UIColor takes CGFloats between 0.0 and 1.0
        
        let rgbValue = Int(self.color)
        
        let red =   CGFloat((rgbValue & 0xFF0000) >> 16) / 0xFF
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 0xFF
        let blue =  CGFloat(rgbValue & 0x0000FF) / 0xFF
        let alpha = CGFloat(1.0)
        // TODO: Fix Colors also for XOS
        #if os(iOS)
        return fixColor(colorScheme: colorScheme, color: UIColor(red: red, green: green, blue: blue, alpha: alpha))
        #else
        return Color(red: red, green: green, blue: blue, opacity: alpha)
        #endif
    }
    #if os(iOS)
    // Fixes the color if it is too dark or too bright depending of the dark/light theme
    func fixColor(colorScheme: ColorScheme, color: UIColor) -> Color {
        var h = CGFloat(0), s = CGFloat(0), b = CGFloat(0), a = CGFloat(0)
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        b = colorScheme == .dark ? fmax(b, 0.2) : fmin(b, 0.75)
        return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
    }
    #endif
}

extension Device {
    var branchValue: Branch {
        get {
            guard let branch = self.branch else { return .unknown }
            return Branch(rawValue: String(branch)) ?? .unknown
        }
        set {
            self.branch = String(newValue.rawValue)
        }
    }
}
