
import SwiftUI

struct DeviceListItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @EnvironmentObject var device: Device
    
    @State private var isUserInput = true
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(device.displayName)
                            .font(.headline.leading(.tight))
                        if (device.updateAvailable) {
                            Icons.update
                        }
                    }
                    HStack {
                        Text(device.address ?? "")
                            .lineLimit(1)
                            .fixedSize()
                            .font(.subheadline.leading(.tight))
                            .lineSpacing(0)
                        
                        Icons.wifi(isOnline: device.isOnline, signalStrength: Int(device.networkRssi))
                            
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
                ActiveToogle(device: device)
                    .frame(alignment: .trailing)
            }
            BrightnesSlider(device: device)
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
