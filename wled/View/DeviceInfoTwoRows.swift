//
//  DeviceInfoTwoRows.swift
//  WLED
//
//  Created by Christophe Gagnier on 2025-12-16.
//


import SwiftUI

struct DeviceInfoTwoRows: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var device: DeviceWithState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(device.device.displayName)
                    .font(.headline.leading(.tight))
                    .lineLimit(2)
                if device.hasUpdateAvailable {
                    Image(systemName: getUpdateIconName())
                }
            }
            HStack {
                // Inner stack to keep the indicator and address tighter
                HStack(spacing: 4) {
                    WebsocketStatusIndicator(currentStatus: device.websocketStatus)
                    Text(device.device.address ?? "")
                        .lineLimit(1)
                        .fixedSize()
                        .font(.subheadline.leading(.tight))
                        .lineSpacing(0)
                }
                Image(uiImage: getSignalImage(isOnline: device.isOnline, signalStrength: Int(device.stateInfo?.info.wifi.signal ?? 0)))
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.primary)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 12)
                if (!device.isOnline) {
                    OfflineSinceText(device: device)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .font(.subheadline.leading(.tight))
                        .foregroundStyle(.secondary)
                        .lineSpacing(0)
                        .minimumScaleFactor(0.6)
                }
                if (device.device.isHidden) {
                    Image(systemName: "eye.slash")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.secondary)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 12)
                    Text("(Hidden)")
                        .lineLimit(1)
                        .font(.subheadline.leading(.tight))
                        .foregroundStyle(.secondary)
                        .lineSpacing(0)
                        .truncationMode(.tail)
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func getUpdateIconName() -> String {
        if #available(iOS 17.0, *) {
            return "arrow.down.circle.dotted"
        } else {
            return "arrow.down.circle"
        }
    }

    func getSignalImage(isOnline: Bool, signalStrength: Int?) -> UIImage {
        let icon = !isOnline || signalStrength == nil || signalStrength == 0 ? "wifi.slash" : "wifi"
        var image: UIImage;
        if #available(iOS 16.0, *) {
            image = UIImage(
                systemName: icon,
                variableValue: getSignalValue(signalStrength: signalStrength)
            )!
        } else {
            image = UIImage(
                systemName: icon
            )!
        }
        image.applyingSymbolConfiguration(UIImage.SymbolConfiguration(hierarchicalColor: .systemBlue))
        return image
    }

    func getSignalValue(signalStrength: Int?) -> Double {
        if let signalStrength {
            if (signalStrength >= -70) {
                return 1
            }
            if (signalStrength >= -85) {
                return 0.64
            }
            if (signalStrength >= -100) {
                return 0.33
            }
        }
        return 0
    }
}

// MARK: - OfflineSinceText

struct OfflineSinceText: View {
    @ObservedObject var device: DeviceWithState
    @Environment(\.locale) private var locale

    private let formatter: RelativeDateTimeFormatter = {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full // Generates "10 minutes ago", "1 hour ago"
        fmt.dateTimeStyle = .named // Allows "yesterday" instead of "1 day ago" if appropriate
        return fmt
    }()

    var body: some View {
        // Update the view every minute to keep the "ago" text fresh
        TimelineView(.periodic(from: .now, by: 60)) { context in
            getOfflineText(now: context.date)
        }
    }

    private func getOfflineText(now: Date) -> Text {
        // lastSeen is Int64 milliseconds. 0 usually means never seen/unknown.
        let lastSeenMs = device.device.lastSeen

        guard lastSeenMs > 0 else {
            return Text("(Offline)")
        }

        formatter.locale = locale
        let lastSeenDate = Date(timeIntervalSince1970: TimeInterval(lastSeenMs) / 1000)
        let diff = now.timeIntervalSince(lastSeenDate)

        // Handle the "less than a minute" case manually
        if diff < 60 {
            return Text("(Offline, less than a minute ago)")
        }

        // For everything else (minutes, hours, days), let Apple handle the linguistics
        let timeString = formatter.localizedString(for: lastSeenDate, relativeTo: now)

        // formatter returns "10 minutes ago", so we prepend "Offline, "
        // Using string interpolation here works because the formatter output is already localized/pluralized
        return Text("(Offline, \(timeString))")
    }
}

// MARK: - Previews

struct DeviceInfoTwoRows_Previews: PreviewProvider {
    static let device = DeviceWithState(
        initialDevice: Device(
            context: PersistenceController.preview.container.viewContext
        )
    )

    static var previews: some View {
        device.device.macAddress = UUID().uuidString
        device.device.originalName = ""
        device.device.address = "192.168.11.101"
        device.device.isHidden = false
        // TODO: #statelessDevice fix device preview
        //        device.isOnline = true
        //        device.networkRssi = -80
        //        device.color = 6244567779
        //        device.brightness = 125
        //        device.isRefreshing = true
        //        device.isHidden = true


        return DeviceInfoTwoRows(device: device)
    }
}

struct OfflineSinceText_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // English (Default)
            previewList
                .previewDisplayName("English")

            // French (Explicit)
            previewList
                .environment(\.locale, Locale(identifier: "fr-CA"))
                .previewDisplayName("French")
        }
        .previewLayout(.sizeThatFits)
    }

    static var previewList: some View {
        VStack(alignment: .leading, spacing: 20) {
            createPreview(offset: -30, label: "Less than a minute")
            createPreview(offset: -15 * 60, label: "15 minutes ago")
            createPreview(offset: -25 * 60 * 60, label: "Yesterday")
            createPreview(offset: -61 * 24 * 60 * 60, label: "2 months ago")
        }
        .padding()
    }

    // Helper to create the device and view
    static func createPreview(offset: TimeInterval, label: String) -> some View {
        let context = PersistenceController.preview.container.viewContext
        let device = Device(context: context)
        // Convert Date to Int64 milliseconds
        device.lastSeen = Int64(Date().addingTimeInterval(offset).timeIntervalSince1970 * 1000)
        let deviceWithState = DeviceWithState(initialDevice: device)

        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.blue)
            OfflineSinceText(device: deviceWithState)
        }
    }
}

