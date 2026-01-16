import SwiftUI
import UIKit

extension Color {
    /// Fixes the color if it is too dark or too bright depending on the dark/light theme.
    /// Used primarily for the Card background color.
    func fixDisplayColor(for colorScheme: ColorScheme) -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // In Dark mode, ensure at least 0.2 brightness (don't disappear into black)
        // In Light mode, ensure max 0.75 brightness (don't disappear into white/be too bright)
        b = colorScheme == .dark ? fmax(b, 0.2) : fmin(b, 0.75)

        return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
    }

    /// Adjusts the color to ensure minimum contrast for UI controls (like Toggle switches)
    /// which often have white components (knobs).
    func ensureContrast(for colorScheme: ColorScheme) -> Color {
        // We only really care about Dark Mode issues where White tint on White thumb is problematic.
        // In Light mode, fixDisplayColor likely handles the "too bright" case, or system colors work better.
        // But the user specifically mentioned Dark Mode issues with White color.

        guard colorScheme == .dark else { return self }

        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // If color is very bright (close to white), we need to darken it for the track
        // to contrast with the White thumb (Brightness 1.0).
        // A brightness of 0.6 provides decent contrast with 1.0.

        if b > 0.8 {
            // Also check saturation. If it's a vivid color (High Saturation),
            // the hue contrast might be enough even if bright?
            // But White Thumb has S=0.
            // Cyan (S=1, B=1) vs White. Visible.
            // Yellow (S=1, B=1) vs White. Harder.
            // White (S=0, B=1) vs White. Invisible.

            // So if Saturation is low, we definitely need to darken.
            if s < 0.3 {
                 return Color(UIColor(hue: h, saturation: s, brightness: 0.5, alpha: a))
            }

            // For other high brightness colors, maybe darken slightly just in case?
            // Let's stick to the low saturation case first as it's the most obvious issue.
        }

        return self
    }
}
