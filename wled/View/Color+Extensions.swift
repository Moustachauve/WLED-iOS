import SwiftUI
import UIKit

extension Color {
    /// Fixes the color if it is too dark or too bright depending of the dark/light theme
    func fixDisplayColor(colorScheme: ColorScheme) -> Color {
        let uiColor = UIColor(self)
        var h = CGFloat(0), s = CGFloat(0), b = CGFloat(0), a = CGFloat(0)

        guard uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }

        b = colorScheme == .dark ? fmax(b, 0.2) : fmin(b, 0.75)
        return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
    }

    /// Ensures a minimum of contrast against white UI elements like Toggle switches
    func ensureContrast(colorScheme: ColorScheme) -> Color {
        let uiColor = UIColor(self)
        var h = CGFloat(0), s = CGFloat(0), b = CGFloat(0), a = CGFloat(0)

        guard uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }

        if colorScheme == .dark {
            // In dark mode, if the color is too close to white (low saturation, high brightness),
            // lower its brightness so that it contrasts well with the white thumb of a Toggle switch
            if s < 0.2 && b > 0.7 {
                b = 0.7
            }
        } else {
            // In light mode, ensure it's not too bright either for contrast purposes
            if s < 0.2 && b > 0.75 {
                b = 0.75
            }
        }

        return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
    }
}
