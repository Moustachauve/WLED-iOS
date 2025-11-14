import SwiftUI

struct DeviceUpdateInstalling: View {
    enum Status {
        case indeterminate, success, failed
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var device: Device
    @ObservedObject var version: Version
    
    @State var offset: CGFloat = 1000
    
    @State var status = Status.indeterminate
    @State var statusString = String(localized: "Starting Up")
    @State var statusDetailsString = String(localized: "Please do not close the app or turn off the device.")
    @State var versionName = ""
    
    var body: some View {
        ZStack {
            Color(.clear)
            VStack {
                Text("Updating \(device.name ?? "(New Device)")")
                    .font(.title2)
                    .bold()
                    .padding(.top)
                    .padding(.trailing)
                    .padding(.leading)
                
                if (status == .indeterminate) {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.bottom, 5)
                } else if (status == .success) {
                    Image(systemName: "checkmark.seal.fill")
                        .resizable()
                        .foregroundColor(.green)
                        .frame(width: 32.0, height: 32.0)
                        .padding(.bottom, 5)
                } else if (status == .failed) {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .foregroundColor(.red)
                        .frame(width: 32.0, height: 32.0)
                        .padding(.bottom, 5)
                }
                
                Text(statusString)
                    .font(.title3)
                    .bold()
                
                Text(versionName)
                    .font(.callout)
                
                if (!statusDetailsString.isEmpty) {
                    Text(statusDetailsString)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Button {
                    NotificationCenter.default.post(
                        name: .didCompleteUpdateInstall,
                        object: nil
                    )
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text(getDismissButtonText())
                        .buttonStyle(.plain)
                }
                .disabled(!canDismiss())
                .padding(.top)
            }
            .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
            .offset(x: 0, y: offset)
            .onAppear {
                withAnimation(.spring()) {
                    offset = 0
                }
                startUpdate()
            }
        }
    }
    
    private func canDismiss() -> Bool {
        switch (status) {
        case .indeterminate:
            return false
        default:
            return true
        }
    }
    
    private func getDismissButtonText() -> LocalizedStringKey {
        switch (status) {
        case .indeterminate:
            return LocalizedStringKey("Cancel")
        default:
            return LocalizedStringKey("Done")
        }
    }
    
    private func startUpdate() {
        let updateService = DeviceUpdateService(device: device, version: version, context: viewContext)
        updateService.determineAsset()
        versionName = updateService.getVersionWithPlatformName()
        if (!updateService.couldDetermineAsset) {
            status = .failed
            statusString = String(localized: "No Compatible Version Found")
            statusDetailsString = String(localized: "no_compatible_version_details")
            return
        }
        if (updateService.isAssetFileCached()) {
            print("Asset is already cached, reusing it.")
            onDownloadCompleted(updateService)
            return
        }
        statusString = String(localized: "Downloading Version")
        updateService.downloadBinary(onCompletion: onDownloadCompleted)
    }
    
    private func onDownloadCompleted(_ updateService: DeviceUpdateService) {
        print("Download is done.")
        statusString = String(localized: "Installing Update")
        updateService.installUpdate(onCompletion: onInstallCompleted, onFailure: onInstallFailed)
    }
    
    private func onInstallCompleted() {
        print("Install is done.")
        status = .success
        statusString = String(localized: "Update Completed!")
        statusDetailsString = ""
        
        Task {
            // Wait 3 seconds before sending a refresh request
            try await Task.sleep(nanoseconds: UInt64(3 * Double(NSEC_PER_SEC)))
            await device.requestManager.addRequest(WLEDRefreshRequest(context: viewContext))
        }
    }
    
    private func onInstallFailed() {
        print("Install failed.")
        status = .failed
        statusString = String(localized: "Update Failed")
        statusDetailsString = String(localized: "update_failed_details")
    }
}

extension Notification.Name {
    static var didCompleteUpdateInstall: Notification.Name {
        return Notification.Name("did complete update install")
    }
}


struct DeviceUpdateInstalling_Previews: PreviewProvider {
    static let device = Device(context: PersistenceController.preview.container.viewContext)
    
    static var previews: some View {
        device.tag = UUID()
        device.version = "0.13.0"
        device.latestUpdateVersionTagAvailable = "v0.14.0"
        device.isEthernet = false
        device.platformName = "esp32"
        
        let version = Version(context: PersistenceController.preview.container.viewContext)
        version.tagName = "v0.14.0"
        
        return DeviceUpdateInstalling(version: version)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(device)
    }
}
