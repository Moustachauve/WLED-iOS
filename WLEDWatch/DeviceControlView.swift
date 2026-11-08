import SwiftUI

/// Single screen split in four quadrants:
///
///     ┌───────────┬───────────┐
///     │   Power   │ Brightness│
///     ├───────────┼───────────┤
///     │ Nightlight│ Remaining │
///     └───────────┴───────────┘
///
/// Tapping the brightness quadrant opens `BrightnessView` (bar + Digital Crown).
struct DeviceControlView: View {
    @State private var controller: DeviceController
    @State private var showBrightness = false

    /// `false` while the page is off-screen: stops polling.
    let isActive: Bool

    init(device: WatchDevice, isActive: Bool = true) {
        self.isActive = isActive
        _controller = State(initialValue: DeviceController(device: device))
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                powerCell
                brightnessCell
            }
            HStack(spacing: 6) {
                nightlightCell
                remainingCell
            }
        }
        .opacity(controller.connection == .offline ? 0.5 : 1)
        .overlay(alignment: .top) { connectionBadge }
        .navigationTitle(controller.device.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBrightness) {
            BrightnessView(controller: controller)
        }
        // Polls while the page is visible; SwiftUI cancels the task when it goes off-screen.
        .task(id: isActive) {
            guard isActive else { return }
            await controller.poll()
        }
    }

    // MARK: - Quadrants

    private var powerCell: some View {
        Button {
            controller.setPower(!controller.isOn)
        } label: {
            Image(systemName: "power")
                .font(.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(controller.isOn ? .yellow : .gray)
        .accessibilityLabel("Power")
        .accessibilityValue(controller.isOn ? "On" : "Off")
    }

    private var brightnessCell: some View {
        Button {
            showBrightness = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "sun.max.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                Text("\(Int(controller.brightness.rounded()))")
                    .font(.title2.monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Brightness")
        .accessibilityValue("\(Int(controller.brightness.rounded())) of \(Int(DeviceController.maxBrightness))")
        .accessibilityHint("Opens the brightness control")
    }

    private var nightlightCell: some View {
        Button {
            controller.setNightlight(!controller.isNightlightOn)
        } label: {
            Image(systemName: controller.isNightlightOn ? "moon.stars.fill" : "moon.stars")
                .font(.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(controller.isNightlightOn ? .indigo : .gray)
        .accessibilityLabel("Nightlight")
        .accessibilityValue(controller.isNightlightOn ? "On" : "Off")
    }

    private var remainingCell: some View {
        VStack(spacing: 2) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundStyle(.secondary)
            if controller.isNightlightOn, let end = controller.nightlightEnd, end > .now {
                Text(timerInterval: .now...end, countsDown: true)
                    .font(.title3.monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Text("--:--")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nightlight time remaining")
    }

    @ViewBuilder
    private var connectionBadge: some View {
        switch controller.connection {
        case .connecting:
            ProgressView().padding(.top, 4)
        case .offline:
            Label("Unreachable", systemImage: "wifi.slash")
                .font(.caption2)
                .padding(4)
                .background(.red, in: Capsule())
        case .online:
            EmptyView()
        }
    }
}
