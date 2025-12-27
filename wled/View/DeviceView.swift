
import SwiftUI

struct DeviceView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var device: DeviceWithState

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
        .navigationTitle(device.device.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
    }
    
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            NavigationLink {
                DeviceEditView(device: device)
            } label: {
                Image(systemName: "gear")
            }
            .overlay(alignment: .bottomTrailing) {
                ToolbarBadge(value: .constant(getToolbarBadgeCount()))
            }
        }
        ToolbarItem(placement: .automatic) {
            Button("Refresh", systemImage: "arrow.clockwise") {
                shouldWebViewRefresh = true
            }
        }
    }
    
    func getDeviceAddress() -> URL? {
        guard let deviceAddress = device.device.address,
                let url = URL(string: "http://\(deviceAddress)") else {
            return nil
        }
        return url
    }
    
    func getToolbarBadgeCount() -> Int {
        return device.hasUpdateAvailable ? 1 : 0
    }
}

#Preview {
    NavigationView {
        DeviceView(device: PreviewData.onlineDevice)
    }
}
