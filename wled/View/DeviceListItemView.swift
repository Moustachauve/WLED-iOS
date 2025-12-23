
import SwiftUI

private struct DeviceGroupBoxStyle: GroupBoxStyle {
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

private extension GroupBoxStyle where Self == DeviceGroupBoxStyle {
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
        GroupBox {
            HStack {
                DeviceInfoTwoRows(device: device)

                Toggle("Turn On/Off", isOn: isOnBinding)
                    .labelsHidden()
                    .frame(alignment: .trailing)
                    .tint(currentDeviceColor)
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
            .tint(currentDeviceColor)
        }
        .groupBoxStyle(.device(color: currentDeviceColor))
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

    private var currentDeviceColor: Color {
        // Depending on your getColor signature, you might need to handle the optional state explicitly
        let colorInt = device.device.getColor(state: device.stateInfo?.state)
        let activeColor = colorFromHex(rgbValue: Int(colorInt))

        if device.isOnline {
            return activeColor
        }

        // Convert to UIColor to easily extract HSB values
        let uiColor = UIColor(activeColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Return a new Color with 0 saturation (Gray), preserving brightness
        return Color(hue: h, saturation: 0, brightness: b, opacity: Double(a))
    }

    func colorFromHex(rgbValue: Int, alpha: Double? = 1.0) -> Color {
        // &  binary AND operator to zero out other color values
        // >>  bitwise right shift operator
        // Divide by 0xFF because UIColor takes CGFloats between 0.0 and 1.0

        let red =   CGFloat((rgbValue & 0xFF0000) >> 16) / 0xFF
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 0xFF
        let blue =  CGFloat(rgbValue & 0x0000FF) / 0xFF
        let alpha = CGFloat(alpha ?? 1.0)

        return fixColor(color: UIColor(red: red, green: green, blue: blue, alpha: alpha))
    }

    // Fixes the color if it is too dark or too bright depending of the dark/light theme
    func fixColor(color: UIColor) -> Color {
        var h = CGFloat(0), s = CGFloat(0), b = CGFloat(0), a = CGFloat(0)
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        b = colorScheme == .dark ? fmax(b, 0.2) : fmin(b, 0.75)
        return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
    }
}

struct DeviceListItemView_Previews: PreviewProvider {
    static let device = DeviceWithState(
        initialDevice: Device(
            context: PersistenceController.preview.container.viewContext
        )
    )

    static var previews: some View {
        // TODO: Improve the creation of fake DeviceWithState for previews
        device.device.macAddress = UUID().uuidString
        device.device.originalName = ""
        device.device.address = "192.168.11.101"
        device.device.isHidden = false
        device.websocketStatus = .connected

        // Create Mock StateInfo using JSON
        // This is much easier than calling the memberwise initializer for Info/Leds/Wifi
        let json = """
        {
            "state": {
                "on": true,
                "bri": 128,
                "seg": [
                    {
                        "id": 0, 
                        "col": [
                            [0, 255, 255], 
                            [0, 0, 0], 
                            [0, 0, 0]
                        ]
                    }
                ]
            },
            "info": {
                "name": "Living Room",
                "ver": "0.14.0",
                "leds": {
                    "count": 30,
                    "pwr": 0,
                    "fps": 0,
                    "maxpwr": 0,
                    "maxseg": 0
                },
                "wifi": {
                    "signal": -60
                }
            }
        }
        """

        // Decode and assign the mock info
        if let data = json.data(using: .utf8),
           let mockState = try? JSONDecoder().decode(DeviceStateInfo.self, from: data) {
            device.stateInfo = mockState
        }

        return DeviceListItemView(
            device: device,
            onTogglePower: { isOn in
                print("Preview: Power toggled to \(isOn)")
            },
            onChangeBrightness: { val in
                print("Preview: Brightness changed to \(val)")
            }
        )
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
