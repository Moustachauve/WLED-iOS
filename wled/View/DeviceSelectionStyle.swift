import SwiftUI

struct DeviceSelectionStyle: ViewModifier {
    var isSelected: Bool
    var color: Color
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        let contrastColor = color.ensureContrast(for: colorScheme)

        return content
        // Prevent system from turning text white on selection
            .foregroundStyle(.primary)
        // Apply Tint/Accent for sliders/toggles with contrast check
            .tint(contrastColor)
            .accentColor(contrastColor)
        // Border
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? color : .clear,
                        lineWidth: isSelected ? Style.selectedBorderWidth : Style.unselectedBorderWidth
                    )
            )
        // Glow effect
            .shadow(color: glowColor, radius: Style.glowRadius, x: 0, y: 0)
    }

    // MARK: Helper properties

    private var glowColor: Color {
        guard isSelected else { return .clear }
        let opacity = colorScheme == .dark ? Style.darkGlowOpacity : Style.lightGlowOpacity
        return color.opacity(opacity)
    }

    enum Style {
        static let selectedOpacity: Double = 1.0
        static let unselectedOpacity: Double = 0.6
        static let selectedBorderWidth: CGFloat = 2.0
        static let unselectedBorderWidth: CGFloat = 0.0
        static let glowRadius: CGFloat = 5.0
        static let darkGlowOpacity: Double = 0.6
        static let lightGlowOpacity: Double = 0.4
    }
}

extension View {
    func applyDeviceSelectionStyle(isSelected: Bool, color: Color) -> some View {
        self.modifier(DeviceSelectionStyle(isSelected: isSelected, color: color))
    }
}
