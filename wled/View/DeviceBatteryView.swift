import SwiftUI

struct DeviceBatteryView: View {
    let batteryLevel: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: getBatteryIconName(level: batteryLevel))
            Text("\(batteryLevel)%")
        }
        .font(.caption2)
        .foregroundStyle(getBatteryColor(level: batteryLevel))
    }

    private func getBatteryIconName(level: Int) -> String {
        switch level {
        case 0...10:
            return "battery.0"
        case 11...35:
            return "battery.25"
        case 36...60:
            return "battery.50"
        case 61...85:
            return "battery.75"
        default:
            return "battery.100"
        }
    }

    private func getBatteryColor(level: Int) -> Color {
        if level <= 20 {
            return .red
        } else {
            return .primary
        }
    }
}

struct DeviceBatteryView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            DeviceBatteryView(batteryLevel: 5)
            DeviceBatteryView(batteryLevel: 25)
            DeviceBatteryView(batteryLevel: 50)
            DeviceBatteryView(batteryLevel: 75)
            DeviceBatteryView(batteryLevel: 100)
        }
    }
}
