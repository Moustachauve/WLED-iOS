import SwiftUI

/// Full-screen brightness control: drag the bar for a quick change,
/// use the Digital Crown for fine adjustment.
struct BrightnessView: View {
    let controller: DeviceController
    @FocusState private var crownFocused: Bool
    /// Mirrors `controller.brightness` for the Digital Crown, which needs a binding.
    @State private var crownValue: Double
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize = 48

    private let range = DeviceController.minBrightness...DeviceController.maxBrightness
    private let accessibilityStep = 15.0

    init(controller: DeviceController) {
        self.controller = controller
        _crownValue = State(initialValue: controller.brightness)
    }

    private var fraction: Double {
        (controller.brightness - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            Text("\(Int(controller.brightness.rounded()))")
                .font(.system(size: valueSize, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(.yellow)
                        .frame(width: max(proxy.size.height, proxy.size.width * fraction))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let x = min(max(drag.location.x / proxy.size.width, 0), 1)
                            controller.setBrightness((range.lowerBound + x * (range.upperBound - range.lowerBound)).rounded())
                        }
                )
            }
            .frame(height: 28)
        }
        .padding(.horizontal, 4)
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownValue,
            from: range.lowerBound,
            through: range.upperBound,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear { crownFocused = true }
        .onChange(of: crownValue) {
            controller.setBrightness(crownValue)
        }
        .onChange(of: controller.brightness) {
            if crownValue != controller.brightness { crownValue = controller.brightness }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brightness")
        .accessibilityValue("\(Int(controller.brightness.rounded())) of \(Int(range.upperBound))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: controller.setBrightness(min(controller.brightness + accessibilityStep, range.upperBound))
            case .decrement: controller.setBrightness(max(controller.brightness - accessibilityStep, range.lowerBound))
            @unknown default: break
            }
        }
    }
}
