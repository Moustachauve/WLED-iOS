
import SwiftUI

struct DeviceAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject private var viewModel = DeviceAddViewModel()

    var body: some View {
        NavigationView {
            VStack {
                switch viewModel.currentStep {
                case .form(let errorMessage):
                    DeviceAddStep1FormView(
                        viewModel: viewModel,
                        errorMessage: errorMessage,
                    )
                case .adding:
                    DeviceAddStep2LoadingView(address: viewModel.address)
                case .success(let device):
                    DeviceAddStep3Success(device: device)
                }
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                if (viewModel.currentStep.isForm) {
                    ToolbarItem {
                        Button(action: {
                            withAnimation {
                                viewModel.submitCreateDevice()
                            }
                        }) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .navigationTitle("New Device")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Step 1: Form

struct DeviceAddStep1FormView: View {

    @ObservedObject var viewModel: DeviceAddViewModel

    let errorMessage: String
    let state = DeviceAddViewModel.Step.self

    var body: some View {
        VStack(alignment: .leading) {
            Text("IP Address or URL")
            TextField("IP Address or URL", text: $viewModel.address)
                .keyboardType(.URL)
                .submitLabel(.done)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            errorMessage.isEmpty ? Color.clear : Color.red
                        )
                )
                .onSubmit {
                    withAnimation {
                        viewModel.submitCreateDevice()
                    }
                }
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(Font.caption.bold())
            }
        }
    }
}

// MARK: - Step 2: Adding, Loading indicator

struct DeviceAddStep2LoadingView: View {
    let address: String

    var body: some View {
        ProgressView()
            .controlSize(ControlSize.large)
            .padding()
        Text("Adding \(address)")
    }
}

// MARK: - Step 3: Success

struct DeviceAddStep3Success: View {
    let device: Device

    var body: some View {
        Image(systemName: "checkmark.seal")
            .font(.system(size: 50))
            .foregroundStyle(.green)
            .padding()
        Text("\(device.displayName) was added")
    }
}

#Preview {
    DeviceAddView()
}
