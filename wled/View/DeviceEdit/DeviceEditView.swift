
import SwiftUI

struct DeviceEditView: View {
    @Environment(\.managedObjectContext) private var viewContext

    enum Field {
        case name
    }

    @StateObject private var viewModel: DeviceEditViewModel
    @ObservedObject private var device: DeviceWithState

    @State private var isFormValid: Bool = true
    @FocusState var isNameFieldFocused: Bool

    let unknownVersion = String(localized: "unknown_version")
    var branchOptions = ["Stable", "Beta"]

    init(device: DeviceWithState) {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: DeviceEditViewModel(device: device, context: context))

        self.device = device
    }


    // MARK: - body

    var body: some View {
        ScrollView {
            GroupBox {
                DeviceInfoTwoRows(device: device)
            }
            .groupBoxStyle(.device(color: device.currentColor))
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))

            VStack(alignment: .leading) {
                Text("Custom Name")
                TextField("Custom Name", text: $viewModel.customName)
                    .focused($isNameFieldFocused)
                    .submitLabel(.done)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Toggle("Hide this Device", isOn: $viewModel.hideDevice)
                .padding(.trailing, 2)
                .padding(.bottom)

            HStack {
                Text("Update Channel")
                Spacer()
                Picker("Update Channel", selection: $viewModel.branch) {
                    ForEach(Branch.allCases.filter { $0 != .unknown }) { branch in
                        Text(LocalizedStringKey(branch.nameKey))
                            .tag(branch)
                            .padding()
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding(.bottom)

            if (device.stateInfo != nil) {
                // TODO: Update this to be its own "helicopter" view
                VStack(alignment: .leading) {
                    if ((device.availableUpdateVersion ?? "").isEmpty) {
                        Text("Your device is up to date")
                        Text(
                            "Version \(device.stateInfo?.info.version ?? unknownVersion)"
                        )
                        HStack {
                            Button(action: {
                                Task {
                                    await viewModel.checkForUpdate()
                                }
                            }) {
                                Text(viewModel.isCheckingForUpdates ? "Checking for Updates" : "Check for Update")
                            }
                            .buttonStyle(.bordered)
                            .padding(.trailing)
                            .disabled(viewModel.isCheckingForUpdates)
                            ProgressView()
                                .opacity(viewModel.isCheckingForUpdates ? 1 : 0)
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
                                Text("From \(device.stateInfo?.info.version ?? unknownVersion) to \(device.availableUpdateVersion ?? unknownVersion)")
                                NavigationLink {
                                    DeviceUpdateDetails(device: device)
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
                .animation(.default, value: device.availableUpdateVersion)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Edit Device")
        .navigationBarTitleDisplayMode(.large)
    }

    func getUpdateIconName() -> String {
        if #available(iOS 17.0, *) {
            return "arrow.down.circle.dotted"
        } else {
            return "arrow.down.circle"
        }
    }
}

struct DeviceEditView_Previews: PreviewProvider {
    static let device = DeviceWithState(
        initialDevice: Device(
            context: PersistenceController.preview.container.viewContext
        )
    )

    static var previews: some View {
        device.device.macAddress = UUID().uuidString
        device.device.originalName = "Original name"
        device.device.customName = "A custom name"
        device.device.address = "192.168.11.101"
        device.device.isHidden = true


        return DeviceEditView(device: device)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
