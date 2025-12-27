
import SwiftUI

struct DeviceGroupBoxStyle: GroupBoxStyle {
    var deviceColor: Color

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
            configuration.content
        }
        .padding()
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .background(deviceColor.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

extension GroupBoxStyle where Self == DeviceGroupBoxStyle {
    static func device(color: Color) -> DeviceGroupBoxStyle {
        .init(deviceColor: color)
    }
}



struct DeviceListItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var device: DeviceWithState

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
        .groupBoxStyle(.device(color: fixedDeviceColor))
        .tint(fixedDeviceColor)
        .accentColor(fixedDeviceColor)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .onAppear() {
            brightness = Double(device.stateInfo?.state.brightness ?? 0)
        }
        .onChange(of: device.stateInfo?.state.brightness) { brightness in
            self.brightness = Double(device.stateInfo?.state.brightness ?? 0)
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

struct DeviceListItemView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceListItemView(
            device: PreviewData.onlineDevice,
            onTogglePower: { isOn in
                print("Preview: Power toggled to \(isOn)")
            },
            onChangeBrightness: { val in
                print("Preview: Brightness changed to \(val)")
            }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
