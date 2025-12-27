
import SwiftUI
import CoreData
import MarkdownUI

struct DeviceUpdateDetails: View {
    // TODO: Pass the version to display instead of only showing the latest one
    // This will allow support for downgrading or chosing a different version
    // in the future.
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var device: DeviceWithState

    @State var showWarningDialog = false
    @State var showInstallingDialog = false
    
    @StateObject var versionViewModel = VersionViewModel()
    
    var body: some View {
        ZStack {
            ScrollView {
                Markdown(versionViewModel.version?.versionDescription ?? "[Unknown Error]")
                    .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Skip This Version") {
                    skipVersion()
                }
                
                Spacer()
                
                Button("Install") {
                    showWarningDialog = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!device.isOnline)
                .confirmationDialog("Are you sure?",
                                    isPresented: $showWarningDialog) {
                    Button("Install Now") {
                        installVersion()
                    }
                } message: {
                    Text("update_disclaimer")
                }
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Version \(versionViewModel.version?.tagName ?? "")")
        .fullScreenCover(isPresented: $showInstallingDialog) {
            if let version = versionViewModel.version {
                DeviceUpdateInstalling(device: device, version: version)
                    .background(BackgroundBlurView())
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCompleteUpdateInstall)) {_ in
            dismiss()
        }
        .onAppear() {
            versionViewModel
                .loadVersion(
                    device.availableUpdateVersion ?? "",
                    context: viewContext
                )
        }
    }
    
    func skipVersion() {
        device.device.skipUpdateTag = device.availableUpdateVersion
        do {
            try viewContext.save()
        } catch {
            // TODO: Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        dismiss()
    }

    func installVersion() {
        showInstallingDialog = true
    }
    
    
}

struct DeviceUpdateDetails_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeviceUpdateDetails(device: PreviewData.deviceWithUpdate)
        }
        // This line is required to provide the Core Data context to the view
        .environment(\.managedObjectContext, PreviewData.viewContext)
    }
}
