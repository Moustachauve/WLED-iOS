
import SwiftUI

struct DeviceAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    enum Field {
        case address, name
    }
    
    @State private var address: String = ""
    @State private var customName: String = ""
    @State private var hideDevice: Bool = false
    @State private var isFormValid: Bool = false
    @FocusState var focusedField: Field?
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(alignment: .leading) {
                    Text("IP Address or URL")
                    TextField("IP Address or URL", text: $address)
                        .focused($focusedField, equals: .address)
                        .keyboardType(.URL)
                        .submitLabel(.next)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(address.isEmpty || isAddressValid() ? Color.clear : Color.red))
                        .onChange(of: address) { _ in
                            validateForm()
                        }
                        .onSubmit {
                            focusedField = .name
                        }
                }
                
                VStack(alignment: .leading) {
                    Text("Custom Name")
                    TextField("Custom Name", text: $customName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.send)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(customName.isEmpty || isNameValid() ? Color.clear : Color.red))
                        .onChange(of: customName) { _ in
                            validateForm()
                        }
                        .onSubmit {
                            addItem()
                        }
                }
                Toggle("Hide this Device", isOn: $hideDevice)
                
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Text("Save")
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("New Device")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func validateForm() {
        let addressIsValid = isAddressValid()
        let nameIsValid = isNameValid()
        isFormValid = addressIsValid && nameIsValid
    }
    
    func isAddressValid() -> Bool {
        // TODO: Add validation that the address doesnt return nil when passed to URL(string:)
        guard let address = removeProtocol(address: address), !address.isEmpty else {
            return false
        }
        
        if let url = NSURL(string: address) {
            if (UIApplication.shared.canOpenURL(url as URL)) {
                return true
            }
        }
        if let url = NSURL(string: "http://\(address)") {
            return UIApplication.shared.canOpenURL(url as URL)
        }
        return false
    }
    
    func isNameValid() -> Bool {
        return true
    }
    
    private func removeProtocol(address: String?) -> String? {
        guard let address else {
            return address
        }
        return address
            .replacingOccurrences(of: "https://", with: "", options: .anchored)
            .replacingOccurrences(of: "http://", with: "", options: .anchored)
    }
    
    private func addItem() {
        guard isFormValid else {
            return
        }
        withAnimation {
            let newItem = Device(context: viewContext)
            newItem.tag = UUID()
            newItem.address = address
            newItem.name = customName
            newItem.isCustomName = !customName.isEmpty
            newItem.isHidden = hideDevice
            newItem.isRefreshing = false
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    DeviceAddView()
}
