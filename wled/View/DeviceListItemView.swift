
import SwiftUI

struct DeviceListItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var device: Device
    
    @State private var isUserInput = true
    @State private var brightness: Double = 0.0
    
    var body: some View {
        HStack {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(getDeviceDisplayName())
                                .font(.headline.leading(.tight))
                            if (hasUpdateAvailable()) {
                                Image(systemName: getUpdateIconName())
                            }
                        }
                        HStack {
                            Text(device.address ?? "")
                                .lineLimit(1)
                                .fixedSize()
                                .font(.subheadline.leading(.tight))
                                .lineSpacing(0)
                            Image(uiImage: getSignalImage(isOnline: device.isOnline, signalStrength: Int(device.networkRssi)))
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.primary)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 12)
                            if (!device.isOnline) {
                                Text("(Offline)")
                                    .lineLimit(1)
                                    .font(.subheadline.leading(.tight))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(0)
                            }
                            if (device.isHidden) {
                                Image(systemName: "eye.slash")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.secondary)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 12)
                                Text("(Hidden)")
                                    .lineLimit(1)
                                    .font(.subheadline.leading(.tight))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(0)
                                    .truncationMode(.tail)
                            }
                            if (device.isRefreshing) {
                                ProgressView()
                                    .controlSize(.mini)
                                    .frame(maxHeight: 12, alignment: .trailing)
                                    .padding(.leading, 1)
                                    .padding(.trailing, 1)
                            }
                        }
                        
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Slider(
                    value: $brightness,
                    in: 0...255,
                    onEditingChanged: { editing in
                        print("device \(device.address ?? "?") brightness is changing: \(editing) - \(brightness)")
                        if (!editing) {
                            let postParam = WLEDStateChange(brightness: Int64(brightness))
                            Task {
                                await device.requestManager.addRequest(WLEDChangeStateRequest(state: postParam, context: viewContext))
                            }
                        }
                    }
                )
                .tint(colorFromHex(rgbValue: Int(device.color)))
            }
            
            Toggle("Turn On/Off", isOn: Binding(get: {device.isPoweredOn}, set: {
                device.isPoweredOn = $0
                let postParam = WLEDStateChange(isOn: $0)
                print("device \(device.address ?? "?") toggled \(postParam)")
                Task {
                    await device.requestManager.addRequest(WLEDChangeStateRequest(state: postParam, context: viewContext))
                }
            }))
            .labelsHidden()
            .frame(alignment: .trailing)
            .tint(colorFromHex(rgbValue: Int(device.color)))
        }
        .onAppear() {
            brightness = Double(device.brightness)
        }
        .onChange(of: device.brightness) { brightness in
            self.brightness = Double(device.brightness)
        }
    }
    
    func getSignalImage(isOnline: Bool, signalStrength: Int) -> UIImage {
        let icon = !isOnline || signalStrength == 0 ? "wifi.slash" : "wifi"
        var image: UIImage;
        if #available(iOS 16.0, *) {
            image = UIImage(
                systemName: icon,
                variableValue: getSignalValue(signalStrength: Int(device.networkRssi))
            )!
        } else {
            image = UIImage(
                systemName: icon
            )!
        }
        image.applyingSymbolConfiguration(UIImage.SymbolConfiguration(hierarchicalColor: .systemBlue))
        return image
    }
    
    func getDeviceDisplayName() -> String {
        let emptyName = String(localized: "(New Device)")
        guard let name = device.name else {
            return emptyName
        }
        return name.isEmpty ? emptyName : name
    }
    
    func hasUpdateAvailable() -> Bool {
        viewContext.performAndWait {
            return !(device.latestUpdateVersionTagAvailable ?? "").isEmpty
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
    
    func getUpdateIconName() -> String {
        if #available(iOS 17.0, *) {
            return "arrow.down.circle.dotted"
        } else {
            return "arrow.down.circle"
        }
    }
}

struct DeviceListItemView_Previews: PreviewProvider {
    static let device = Device(context: PersistenceController.preview.container.viewContext)
    
    static var previews: some View {
        device.tag = UUID()
        device.name = ""
        device.address = "192.168.11.101"
        device.isHidden = false
        device.isOnline = true
        device.networkRssi = -80
        device.color = 6244567779
        device.brightness = 125
        device.isRefreshing = true
        device.isHidden = true
        
        
        return DeviceListItemView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(device)
    }
}
