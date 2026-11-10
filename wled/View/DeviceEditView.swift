
import SwiftUI
import MarkdownUI

struct DeviceEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var device: Device
    
    enum Field {
        case name
    }
    
    @State private var address: String = ""
    @State private var customName: String = ""
    @State private var hideDevice: Bool = false
    @State private var branch = ""
    @State private var isFormValid: Bool = true
    @State private var isCheckingForUpdates: Bool = false
    @FocusState var isNameFieldFocused: Bool
    @State var showInstallingDialog = false
    @State private var showBetaDisclaimerDialog = false
    @State private var shouldStartBetaInstall = false
    @Binding var reloadParent: Bool

    @StateObject var versionViewModel = VersionViewModel()
    
    let unknownVersion = String(localized: "unknown_version")
    var branchOptions = ["Stable", "Beta"]
    
    init(reloadParent: Binding<Bool>) {
        _reloadParent = reloadParent
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("IP Address or URL")
                TextField("IP Address or URL", text: $address)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
            }
            
            VStack(alignment: .leading) {
                Text("Custom Name")
                TextField("Custom Name", text: $customName)
                    .focused($isNameFieldFocused)
                    .submitLabel(.done)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: isNameFieldFocused) { isFocused in
                        if (!isFocused) {
                            let wasCustomName = device.isCustomName
                            if (!customName.isEmpty) {
                                device.name = customName
                            } else if (wasCustomName) {
                                // If we used to have a custom name and we no longer have one,
                                // clear the custom name so the normal name can be picked up later
                                device.name = ""
                            }
                            device.isCustomName = !customName.isEmpty
                            saveDevice()
                        }
                    }
            }
            
            Toggle("Hide this Device", isOn: $hideDevice)
                .onChange(of: hideDevice) { newValue in
                    device.isHidden = newValue
                    saveDevice()
                }
                .padding(.trailing, 2)
                .padding(.bottom)
            
            HStack {
                Text("Update Channel")
                Spacer()
                Picker("Update Channel", selection: $branch) {
                    ForEach(branchOptions, id: \.self) {
                        Text(LocalizedStringKey($0))
                            .padding()
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .onChange(of: branch) { newValue in
                    let newBranch = newValue == "Beta" ? Branch.beta : Branch.stable
                    if newBranch == device.branchValue {
                        return
                    }
                    print("language changed! \(newBranch)")
                    device.branchValue = newBranch
                    saveDevice()
                    installVersion(versionTag: device.version ?? "")
                }
            }
            .padding(.bottom)
            
            VStack(alignment: .leading) {
                if ((device.latestUpdateVersionTagAvailable ?? "").isEmpty) {
                    Text("Your device is up to date")
                    Text("Version \(device.version ?? unknownVersion)")
                    HStack {
                        Button(action: {
                            Task {
                                await checkForUpdate()
                            }
                        }) {
                            Text(isCheckingForUpdates ? "Checking for Updates" : "Check for Update")
                        }
                        .buttonStyle(.bordered)
                        .padding(.trailing)
                        .disabled(isCheckingForUpdates)
                        ProgressView()
                            .opacity(isCheckingForUpdates ? 1 : 0)
                    }
                } else {
                    HStack {
                        Image(systemName: getUpdateIconName())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30.0, height: 30.0)
                            .padding(.trailing)
                        VStack(alignment: .leading) {
                            Text("Update Available")
                            Text("From \(device.version ?? unknownVersion) to \(device.latestUpdateVersionTagAvailable ?? unknownVersion)")
                            NavigationLink {
                                DeviceUpdateDetails()
                                    .environmentObject(device)
                            } label: {
                                Text("See Update")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            
            if let betaVersion = versionViewModel.latestBetaVersion,
               let betaTagName = betaVersion.tagName,
               ReleaseService.isVersionNewer(releaseTag: betaTagName, than: device.version ?? "") {
                BetaUpdateAvailableCard(
                    betaTagName: betaTagName,
                    onTryBeta: {
                        showBetaDisclaimerDialog = true
                    }
                )
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Edit Device")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            address = device.address ?? ""
            customName = device.isCustomName ? (self.device.name ?? "") : ""
            hideDevice = device.isHidden
            branch = device.branchValue == Branch.beta ? "Beta" : "Stable"
            versionViewModel.loadLatestBetaVersion(context: viewContext)
        }
        .sheet(isPresented: $showBetaDisclaimerDialog, onDismiss: {
            if shouldStartBetaInstall, let betaTag = versionViewModel.latestBetaVersion?.tagName {
                shouldStartBetaInstall = false
                installVersion(versionTag: betaTag)
            }
        }) {
            if let betaVersion = versionViewModel.latestBetaVersion {
                BetaUpdateDisclaimerSheet(
                    version: betaVersion,
                    onCancel: {
                        showBetaDisclaimerDialog = false
                    },
                    onAccept: {
                        shouldStartBetaInstall = true
                        showBetaDisclaimerDialog = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showInstallingDialog) {
            if let version = versionViewModel.version {
                DeviceUpdateInstalling(version: version)
                    .background(BackgroundBlurView())
                    .onDisappear {
                        reloadParent = true
                    }
            } else {
                ZStack {
                    Color(.clear)
                    VStack {
                        ProgressView()
                            .frame(maxHeight: 18, alignment: .trailing)
                        Text("Loading...")
                            .padding(.bottom, 2)

                        Button {
                            showInstallingDialog = false
                        } label: {
                            Text("Cancel")
                                .buttonStyle(.plain)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 20)
                }
                .background(BackgroundBlurView())
            }
        }
    }
    
    private func saveDevice() {
        device.isRefreshing = false
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func checkForUpdate() async {
        withAnimation {
            isCheckingForUpdates = true
        }
        print("Refreshing available Releases")
        let releaseService = ReleaseService(context: viewContext)
        await releaseService.refreshVersions()
        releaseService.sanitizeDeviceUpdateTags()
        versionViewModel.loadLatestBetaVersion(context: viewContext)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: WLEDNativeApp.dateLastUpdateKey)
        
        device.skipUpdateTag = ""
        withAnimation {
            Task {
                await device.requestManager.addRequest(WLEDRefreshRequest(context: viewContext))
            }
            isCheckingForUpdates = false
        }
    }
    
    func getUpdateIconName() -> String {
        if #available(iOS 17.0, *) {
            return "arrow.down.circle.dotted"
        } else {
            return "arrow.down.circle"
        }
    }
    
    func installVersion(versionTag: String) {
        print("Opening install dialog")
        versionViewModel.loadVersion(versionTag, context: viewContext)
        showInstallingDialog = true
    }
}

struct BetaUpdateAvailableCard: View {
    let betaTagName: String
    let onTryBeta: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ExperimentIcon()
                    .fill(Color.accentColor)
                    .frame(width: 22, height: 22)
                Text(String(format: String(localized: "beta_version_available"), betaTagName))
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            if let url = URL(string: String(localized: "beta_cloudapp_url")) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text("learn_more_beta_app")
                            .underline()
                            .multilineTextAlignment(.leading)
                        Image(systemName: "link")
                    }
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                }
            }
            Text("beta_migration_card_warning")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button(action: onTryBeta) {
                Text("try_new_beta_version")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct BetaUpdateDisclaimerSheet: View {
    @ObservedObject var version: Version
    let onCancel: () -> Void
    let onAccept: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(String(format: String(localized: "beta_update_disclaimer_title"), version.tagName ?? ""))
                            .font(.title3)
                            .bold()
                    }
                    
                    Text("beta_update_disclaimer_warning")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(8)
                    
                    if let description = version.versionDescription, !description.isEmpty {
                        Divider()
                        Markdown(description)
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button("Cancel", role: .cancel, action: onCancel)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button(role: .destructive, action: onAccept) {
                        Text("Install Now")
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
                .background(.bar)
            }
        }
    }
}

struct ExperimentIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 960.0
        let scaleY = rect.height / 960.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }
        var path = Path()
        // Outer flask contour (Material Symbols `experiment` 960x960 viewport)
        path.move(to: pt(200, 840))
        path.addQuadCurve(to: pt(127.5, 794.5), control: pt(149, 840))
        path.addQuadCurve(to: pt(138, 710), control: pt(106, 749))
        path.addLine(to: pt(360, 440))
        path.addLine(to: pt(360, 200))
        path.addLine(to: pt(320, 200))
        path.addQuadCurve(to: pt(291.5, 188.5), control: pt(303, 200))
        path.addQuadCurve(to: pt(280, 160), control: pt(280, 177))
        path.addQuadCurve(to: pt(291.5, 131.5), control: pt(280, 143))
        path.addQuadCurve(to: pt(320, 120), control: pt(303, 120))
        path.addLine(to: pt(640, 120))
        path.addQuadCurve(to: pt(668.5, 131.5), control: pt(657, 120))
        path.addQuadCurve(to: pt(680, 160), control: pt(680, 143))
        path.addQuadCurve(to: pt(668.5, 188.5), control: pt(680, 177))
        path.addQuadCurve(to: pt(640, 200), control: pt(657, 200))
        path.addLine(to: pt(600, 200))
        path.addLine(to: pt(600, 440))
        path.addLine(to: pt(822, 710))
        path.addQuadCurve(to: pt(832.5, 794.5), control: pt(854, 749))
        path.addQuadCurve(to: pt(760, 840), control: pt(811, 840))
        path.addLine(to: pt(200, 840))
        path.closeSubpath()
        
        // Liquid fill trapezoid inside flask
        path.move(to: pt(280, 720))
        path.addLine(to: pt(680, 720))
        path.addLine(to: pt(544, 560))
        path.addLine(to: pt(416, 560))
        path.addLine(to: pt(280, 720))
        path.closeSubpath()
        
        // Inner cutout (counter-clockwise for non-zero winding rule)
        path.move(to: pt(200, 760))
        path.addLine(to: pt(760, 760))
        path.addLine(to: pt(520, 468))
        path.addLine(to: pt(520, 200))
        path.addLine(to: pt(440, 200))
        path.addLine(to: pt(440, 468))
        path.addLine(to: pt(200, 760))
        path.closeSubpath()
        
        return path
    }
}

struct DeviceEditView_Previews: PreviewProvider {
    static let device = Device(context: PersistenceController.preview.container.viewContext)
    
    static var previews: some View {
        device.tag = UUID()
        device.name = "A custom name"
        device.isCustomName = true
        device.address = "192.168.11.101"
        device.isHidden = true
        device.version = "1.2.3"
        device.latestUpdateVersionTagAvailable = "v1.2.4"
        
        
        return DeviceEditView(reloadParent: .constant(false))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(device)
    }
}
