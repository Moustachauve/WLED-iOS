import Foundation
import OSLog

/// Manages changelog display state, tracking which version the user last saw
/// and determining whether to present the "What's New" sheet.
///
/// On init, automatically checks if there are new changelogs to show.
/// On first install (no stored version), saves the current version silently.
final class ChangelogViewModel: ObservableObject {

    // MARK: - Constants

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ca.cgagnier.wled-native",
        category: "ChangelogViewModel"
    )
    private static let lastChangelogVersionKey = "lastChangelogVersionSeen"

    // MARK: - Published State

    /// The assembled markdown content to display. Non-nil means the sheet should be shown.
    @Published var changelogContent: String?

    // MARK: - Dependencies

    private let changelogProvider: ChangelogProvider
    private let currentVersion: String

    // MARK: - Init

    init(changelogProvider: ChangelogProvider = ChangelogProvider()) {
        self.changelogProvider = changelogProvider
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        checkChangelog()
    }

    // MARK: - Public API

    /// Dismisses the changelog sheet and saves the current version as "last seen".
    func dismiss() {
        UserDefaults.standard.set(currentVersion, forKey: Self.lastChangelogVersionKey)
        changelogContent = nil
    }

    /// Shows all changelogs from the beginning of time (for the Settings menu).
    func showAllChangelogs() {
        let content = changelogProvider.getChangelog(
            lastSeenVersion: "0.0.0",
            currentVersion: currentVersion
        )
        if let content, !content.isEmpty {
            changelogContent = content
        }
    }

    // MARK: - Private

    private func checkChangelog() {
        let lastSeenVersion = UserDefaults.standard.string(forKey: Self.lastChangelogVersionKey) ?? ""

        if lastSeenVersion.isEmpty {
            // First install — don't show changelog, just save the current version
            Self.logger.info("First install detected, saving current version \(self.currentVersion) as last seen")
            UserDefaults.standard.set(currentVersion, forKey: Self.lastChangelogVersionKey)
            return
        }

        if lastSeenVersion == currentVersion {
            // Already saw the latest version's changelog
            return
        }

        Self.logger.info("Version changed from \(lastSeenVersion) to \(self.currentVersion), checking changelogs")

        let content = changelogProvider.getChangelog(
            lastSeenVersion: lastSeenVersion,
            currentVersion: currentVersion
        )

        if let content, !content.isEmpty {
            changelogContent = content
        } else {
            // No changelogs to show, but version changed — save so we don't check again
            UserDefaults.standard.set(currentVersion, forKey: Self.lastChangelogVersionKey)
        }
    }
}
