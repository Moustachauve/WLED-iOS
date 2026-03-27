1. **Update `wled/ViewModel/DeviceWebsocketListViewModel.swift`**
   - Add `@Published var onlineDevices: [DeviceWithState] = []` and `@Published var offlineDevices: [DeviceWithState] = []`.
   - Add `private let offlineGracePeriod: TimeInterval = 60`.
   - Move the `isConsideredOnline(_ device: DeviceWithState, at referenceTime: Date) -> Bool` logic from `DeviceListView` into the view model.
   - Add `private var timerCancellable: AnyCancellable?` and `private var cancellables = Set<AnyCancellable>()`.
   - Set up Combine pipelines to observe `showHiddenDevices` and `allDevicesWithState` and timer publishers, triggering a method `updateFilteredDevices` on a background queue, then updating `onlineDevices` and `offlineDevices` on the main thread.

2. **Refactor `wled/View/DeviceListView.swift`**
   - Remove `onlineDevices`, `offlineDevices`, `isConsideredOnline`, `offlineGracePeriod`, `timer`, and `currentTime`.
   - Replace usages of `onlineDevices` and `offlineDevices` with `viewModel.onlineDevices` and `viewModel.offlineDevices`.
   - Use `.onChange(of: showHiddenDevices) { viewModel.showHiddenDevices = $0 }` and `.onAppear { viewModel.showHiddenDevices = showHiddenDevices }` to sync `showHiddenDevices` to the view model.

3. **Verify Code Changes**
   - Check modified files with `read_file` to ensure syntax is correct.
   - Run compilation using `xcodebuild -project wled.xcodeproj -scheme wled -destination 'generic/platform=iOS Simulator,name=iPhone 15' build` to verify there are no compilation errors.
   - Run tests using `xcodebuild -project wled.xcodeproj -scheme wled -destination 'generic/platform=iOS Simulator,name=iPhone 15' test` to verify no regressions.

4. **Complete pre commit steps**
   - Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.

5. **Submit the change**
   - Submit the change with an appropriate commit message.
