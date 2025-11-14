
import SwiftUI

struct DeviceView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var device: Device
    
    @State var showDownloadFinished = false
    @State var shouldWebViewRefresh = false
    
    @State var showEditDeviceView = false
    
    var body: some View {
        ZStack {
            WebView(url: getDeviceAddress(), reload: $shouldWebViewRefresh) { filePathDestination in
                withAnimation {
                    showDownloadFinished = true
                    Task {
                        try await Task.sleep(nanoseconds: UInt64(3 * Double(NSEC_PER_SEC)))
                        showDownloadFinished = false
                    }
                }
            }
            if (showDownloadFinished) {
                VStack {
                    Spacer()
                    Text("Download Completed")
                        .font(.title3)
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(15)
                        .padding(.bottom)
                }
            }
        }
        .navigationTitle(getDeviceName())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
    }
    
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            NavigationLink {
                DeviceEditView()
                    .environmentObject(device)
            } label: {
                Image(systemName: "gear")
            }
            .overlay(alignment: .bottomTrailing) {
                ToolbarBadge(value: .constant(getToolbarBadgeCount()))
            }
        }
        ToolbarItem(placement: .automatic) {
            Button {
                shouldWebViewRefresh = true
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }
    
    func getDeviceAddress() -> URL? {
        guard let deviceAddress = device.address else {
            return nil
        }
        return URL(string: "http://\(deviceAddress)")!
    }
    
    func getToolbarBadgeCount() -> Int {
        return (device.latestUpdateVersionTagAvailable ?? "").isEmpty ? 0 : 1
    }
    
    private func getDeviceName() -> String {
        guard let name = device.name, !name.isEmpty else {
            return String(localized: "(New Device)")
        }
        return name
    }
}

struct DeviceView_Previews: PreviewProvider {
    static let device = Device(context: PersistenceController.preview.container.viewContext)
    
    static var previews: some View {
        device.tag = UUID()
        device.name = ""
        device.address = "google.com"
        device.isOnline = true
        device.networkRssi = -80
        device.color = 6244567779
        device.brightness = 125
        
        return NavigationView{
            DeviceView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
                .environmentObject(device)
        }
    }
}
