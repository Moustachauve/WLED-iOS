

import SwiftUI
import CoreData

//  This helper class creates the correct `DeviceListView` depending on the iOS version
struct DeviceListViewFabric {
    @MainActor @ViewBuilder
    static func makeWindow() -> some View {
        if #available(iOS 16.0, *) {
            DeviceListView()
        } else {
            OldDeviceListView()
        }
    }
}

@available(macOS 15.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
struct DeviceListView: View {
    
    @SceneStorage(WLED.showHiddenDevices.rawValue) private var showHiddenDevices: Bool = false
    @SceneStorage(WLED.showOfflineDevices.rawValue) private var showOfflineDevices: Bool = true
    
    private static let sort = [
        SortDescriptor(\Device.name, comparator: .localized, order: .forward)
    ]
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(sortDescriptors: sort, animation: .default)
    private var devices: FetchedResults<Device>
    
    @FetchRequest(sortDescriptors: sort, animation: .default)
    private var devicesOffline: FetchedResults<Device>
    
    @State private var timer: Timer? = nil
    
    @State private var selection: Device? = nil
    
    private let discoveryService = DiscoveryService()
    
    //MARK: - UI
    
    var body: some View {
        #if os(macOS)
        NavigationStack {
            list
                .toolbarTitleDisplayMode(.inlineLarge)
        }
            .onAppear(perform: appearAction)
            .onDisappear(perform: disappearAction)
            .onChange(of: showHiddenDevices, initial: false) { _,_ in updateFilter() }
        #elseif os(iOS)
        NavigationSplitView {
            list
                .navigationBarTitleDisplayMode(.large)
        } detail: {
            detailView
        }
            .onAppear(perform: appearAction)
            .onDisappear(perform: disappearAction)
            .onChange(of: showHiddenDevices) { _ in updateFilter() }
        #endif
    }
    
    var list: some View {
        List(selection: $selection) {
            Section(header: Text("Online Devices")) {
                DeviceList(devices: devices)
            }
            if !devicesOffline.isEmpty && showOfflineDevices {
                Section(header: Text("Offline Devices")) {
                    DeviceList(devices: devicesOffline)
                }
            }
        }
            .listStyle(PlainListStyle())
            .refreshable(action: refreshList)
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let device = selection {
            NavigationStack {
                DeviceView()
            }
                .environmentObject(device)
        } else {
            Text("Select A Device")
                .font(.title2)
        }
    }
    
    //MARK: - Actions
    
    @Sendable
    private func refreshList() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { discoveryService.scan() }
            group.addTask { await refreshDevices() }
        }
    }
    
    private func updateFilter() {
        print("Update Filter")
        if showHiddenDevices {
            devices.nsPredicate = NSPredicate(format: "isOnline == %@", NSNumber(value: true))
            devicesOffline.nsPredicate =  NSPredicate(format: "isOnline == %@", NSNumber(value: false))
        } else {
            devices.nsPredicate = NSPredicate(format: "isOnline == %@ AND isHidden == %@", NSNumber(value: true), NSNumber(value: false))
            devicesOffline.nsPredicate =  NSPredicate(format: "isOnline == %@ AND isHidden == %@", NSNumber(value: false), NSNumber(value: false))
        }
    }
    
    //  Instead of using a timer, use the WebSocket API to get notified about changes
    //  Cancel the connection if the view disappears and reconnect as soon it apears again
    private func appearAction() {
        updateFilter()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                print("auto-refreshing")
                await refreshList()
                await refreshDevices()
            }
        }
        discoveryService.scan()
    }
    
    private func disappearAction() {
        timer?.invalidate()
    }
    
    @Sendable
    private func refreshDevices() async {
        await withTaskGroup(of: Void.self) { group in
            devices.forEach { refreshDevice(device: $0, group: &group) }
            devicesOffline.forEach { refreshDevice(device: $0, group: &group) }
        }
    }
    
    private func refreshDevice(device: Device, group: inout TaskGroup<Void>) {
        // Don't start a refresh request when the device is not done refreshing.
        if (!device.isRefreshing) {
            return
        }
        self.viewContext.performAndWait {
            device.isRefreshing = true
            group.addTask {
                await device.getRequestManager().addRequest(WLEDRefreshRequest())
            }
        }
        
    }
}

@available(iOS 16.0, macOS 13, tvOS 16.0, watchOS 9.0, *)
#Preview("iOS 16") {
    DeviceListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

    
//MARK: - OLD iOS 15

@available(iOS, deprecated: 16, message: "This implementaion is only for iOS 15 to support the old UI.")
struct OldDeviceListView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var addDeviceButtonActive: Bool = false
    
    @State private var firstLoad = true
    
    @StateObject private var filter = DeviceListFilterAndSort(showHiddenDevices: false)
    
    private let discoveryService = DiscoveryService()
    
    var body: some View {
        NavigationView {
            FetchedObjects(predicate: filter.getOnlineFilter(), sortDescriptors: filter.getSortDescriptors()) { (devices: [Device]) in
                FetchedObjects(predicate: filter.getOfflineFilter(), sortDescriptors: filter.getSortDescriptors()) { (devicesOffline: [Device]) in
                    list(devices: devices, devicesOffline: devicesOffline)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Image(.wledLogoAkemi)
                                .resizable()
                                .scaledToFit()
                                .padding(2)
                        }
                        .frame(maxWidth: 200)
                    }
                    ToolbarItem {
                        Menu {
                            Section {
                                Button {
                                    addDeviceButtonActive.toggle()
                                } label: {
                                    Label("Add New Device", systemImage: "plus")
                                }
                                Button {
                                    withAnimation {
                                        filter.showHiddenDevices = !filter.showHiddenDevices
                                    }
                                } label: {
                                    if (filter.showHiddenDevices) {
                                        Label("Hide Hidden Devices", systemImage: "eye.slash")
                                    } else {
                                        Label("Show Hidden Devices", systemImage: "eye")
                                    }
                                }
                            }
                            Section {
                                Link(destination: URL(string: "https://kno.wled.ge/")!) {
                                    Label("WLED Documentation", systemImage: "questionmark.circle")
                                }
                            }
                        } label: {
                            Label("Menu", systemImage: "ellipsis.circle")
                        }
                    }
                }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .sheet(isPresented: $addDeviceButtonActive, content: DeviceAddView.init)
                VStack {
                    Text("Select A Device")
                        .font(.title2)
                }
            }
        }
    }
    
    private func list(devices: [Device], devicesOffline: [Device]) -> some View {
        List {
            ForEach(devices, id: \.tag) { device in
                NavigationLink {
                    DeviceView()
                        .environmentObject(device)
                } label: {
                    DeviceListItemView()
                        .environmentObject(device)
                }
                .environmentObject(device)
                .swipeActions(allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteItems(device: device)
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
            }
            Section(header: Text("Offline Devices")) {
                ForEach(devicesOffline, id: \.tag) { device in
                    NavigationLink {
                        DeviceView()
                            .environmentObject(device)
                    } label: {
                        DeviceListItemView()
                            .environmentObject(device)
                    }
                    .swipeActions(allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteItems(device: device)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .opacity(devicesOffline.count > 0 ? 1 : 0)
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await refreshDevices(devices: devices + devicesOffline)
            discoveryService.scan()
        }
        .onAppear(perform: {
            Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                Task {
                    print("auto-refreshing")
                    await refreshDevices(devices: devices + devicesOffline)
                }
            }
            Task {
                print("Initial refresh and scan")
                await refreshDevices(devices: devices + devicesOffline)
                discoveryService.scan()
            }
        })
    }
    
    private func deleteItems(device: Device) {
        withAnimation {
            viewContext.delete(device)
            
            do {
                try viewContext.save()
            } catch {
                // TODO: check for changes and fix error message
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func refreshDevices(devices: [Device]) async {
        await withTaskGroup(of: Void.self) { [self] group in
            for device in devices {
                // Don't start a refresh request when the device is not done refreshing.
                if (!self.firstLoad && device.isRefreshing) {
                    continue
                }
                group.addTask {
                    device.isRefreshing = true
                    await device.refresh()
                    
                }
            }
            self.firstLoad = false
        }
    }
}

@available(iOS, deprecated: 16, message: "This implementaion is only for iOS 15 to support the old UI.")
class DeviceListFilterAndSort: ObservableObject {
    
    @Published var showHiddenDevices: Bool
    @Published private var sort = [
        NSSortDescriptor(keyPath: \Device.isOnline, ascending: false),
        NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:))),
    ]

    init(showHiddenDevices: Bool) {
        self.showHiddenDevices = showHiddenDevices
    }
    
    func getSortDescriptors() -> [NSSortDescriptor] {
        return sort
    }
    
    func getOnlineFilter() -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            getOnlineFilter(isOnline: true),
            getHiddenFilterFormat()
        ])
    }
    
    func getOfflineFilter() -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            getOnlineFilter(isOnline: false),
            getHiddenFilterFormat()
        ])
    }
    
    private func getOnlineFilter(isOnline: Bool) -> NSPredicate {
        return NSPredicate(format: "isOnline == %@", NSNumber(value: isOnline))
    }
    
    private func getHiddenFilterFormat() -> NSPredicate {
        if (showHiddenDevices) {
            return NSPredicate(value: true)
        }
        
        return NSPredicate(format: "isHidden == %@", NSNumber(value: false))
    }
}

@available(iOS, deprecated: 16, message: "This implementaion is only for iOS 15 to support the old UI.")
#Preview("iOS 15") {
    OldDeviceListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
