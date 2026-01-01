
import SwiftUI


struct DeviceListItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var device: DeviceWithState

    var isSelected: Bool = false

    // MARK: - Actions
    var onTogglePower: (Bool) -> Void
    var onChangeBrightness: (Int) -> Void

    @State private var brightness: Double = 0.0

    var body: some View {
        let fixedDeviceColor = fixColor(device.currentColor)

        GroupBox {
            HStack {
                DeviceInfoTwoRows(device: device)

                Toggle("Turn On/Off", isOn: isOnBinding)
                    .labelsHidden()
                    .frame(alignment: .trailing)
            }

            Slider(
                value: $brightness,
                in: 0.0...255.0,
                onEditingChanged: { editing in
                    // Call the brightness closure when dragging ends
                    if !editing {
                        onChangeBrightness(Int(brightness))
                    }
                }
            )
        }
        .applyDeviceSelectionStyle(isSelected: isSelected, color: fixedDeviceColor)
        .animation(.linear(duration: 0.3), value: fixedDeviceColor)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .onAppear() {
            brightness = Double(device.stateInfo?.state.brightness ?? 0)
        }
        .onChange(of: device.stateInfo?.state.brightness) { brightness in
            withAnimation(.spring()) {
                self.brightness = Double(device.stateInfo?.state.brightness ?? 0)
            }
        }
    }

    private var isOnBinding: Binding<Bool> {
        Binding(get: {
            device.stateInfo?.state.isOn ?? false
        }, set: { isOn in
            onTogglePower(isOn)
        })
    }

    // Fixes the color if it is too dark or too bright depending of the dark/light theme
    private func fixColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var h = CGFloat(0), s = CGFloat(0), b = CGFloat(0), a = CGFloat(0)
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        b = colorScheme == .dark ? fmax(b, 0.2) : fmin(b, 0.75)
        return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
    }
}

// MARK: - DeviceGroupBoxStyle

struct DeviceGroupBoxStyle: GroupBoxStyle {
    var deviceColor: Color

    func makeBody(configuration: Configuration) -> some View {
        CardGroupBoxStyle(style: .device(color: deviceColor))
            .makeBody(configuration: configuration)
    }
}

extension GroupBoxStyle where Self == DeviceGroupBoxStyle {
    static func device(color: Color) -> DeviceGroupBoxStyle {
        .init(deviceColor: color)
    }
}

// MARK: - DeviceSelectionStyle

struct DeviceSelectionStyle: ViewModifier {
    var isSelected: Bool
    var color: Color
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .groupBoxStyle(DeviceGroupBoxStyle(deviceColor: backgroundColor))
        // Prevent system from turning text white on selection
            .foregroundStyle(.primary)
        // Apply Tint/Accent for sliders/toggles
            .tint(color)
            .accentColor(color)
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

    private var backgroundColor: Color {
        isSelected
        ? color.opacity(Style.selectedOpacity)
        : color.opacity(Style.unselectedOpacity)
    }

    private enum Style {
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


struct DeviceListItemView_Previews: PreviewProvider {
    static var previews: some View {
        let device = PreviewData.onlineDevice

        VStack(alignment: .leading) {
            Text("1st Selected, 2nd unselected")
            DeviceListItemView(
                device: device,
                isSelected: true,
                onTogglePower: { isOn in
                    print("Preview: Power toggled to \(isOn)")
                    device.stateInfo?.state.isOn = isOn
                },
                onChangeBrightness: { val in
                    print("Preview: Brightness changed to \(val)")
                    device.stateInfo?.state.brightness = Int64(val)
                }
            )
            DeviceListItemView(
                device: device,
                onTogglePower: { isOn in
                    print("Preview: Power toggled to \(isOn)")
                    device.stateInfo?.state.isOn = isOn
                },
                onChangeBrightness: { val in
                    print("Preview: Brightness changed to \(val)")
                    device.stateInfo?.state.brightness = Int64(val)
                }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
