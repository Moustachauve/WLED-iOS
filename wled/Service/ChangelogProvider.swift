import Foundation
import OSLog

/// Reads and assembles changelog markdown from the app bundle's `Changelog` folder.
///
/// Changelog files are named using semantic versioning (e.g. `7.0.0.md`, `7.1.0.md`).
/// The provider filters files to show only versions newer than the user's last-seen
/// version up to the current app version, then concatenates them into a single
/// markdown string with version headers.
final class ChangelogProvider {

    // MARK: - Constants

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ca.cgagnier.wled-native",
        category: "ChangelogProvider"
    )
    private static let changelogDirectory = "Changelog"
    private static let markdownExtension = "md"
    private static let devFilename = "dev"
    private static let defaultVersion = "0.0.0"

    // MARK: - Public API

    /// Returns assembled markdown for all changelog entries between `lastSeenVersion`
    /// and `currentVersion`, or `nil` if there are no matching entries.
    ///
    /// - Parameters:
    ///   - lastSeenVersionStr: The version string the user last saw (e.g. `"7.0.0"`).
    ///   - currentVersionStr: The current app version string (e.g. `"7.1.0"`).
    /// - Returns: A combined markdown string, or `nil` if no changelogs apply.
    func getChangelog(lastSeenVersion lastSeenVersionStr: String, currentVersion currentVersionStr: String) -> String? {
        guard let currentVersion = SemanticVersion(currentVersionStr) else {
            Self.logger.error("Invalid current version string: \(lastSeenVersionStr)")
            return nil
        }
        let lastSeenVersion = SemanticVersion(lastSeenVersionStr) ?? SemanticVersion(Self.defaultVersion)!

        let validChangelogs = getValidChangelogs(lastSeenVersion: lastSeenVersion, currentVersion: currentVersion)
        guard !validChangelogs.isEmpty else {
            return nil
        }

        return buildChangelogContent(validChangelogs)
    }

    // MARK: - Private Helpers

    private func getValidChangelogs(lastSeenVersion: SemanticVersion, currentVersion: SemanticVersion) -> [ChangelogFile] {
        guard let changelogURL = Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: Self.changelogDirectory),
              let contents = try? FileManager.default.contentsOfDirectory(at: changelogURL, includingPropertiesForKeys: nil)
        else {
            // Try alternative: look for files in the Changelog folder reference
            return getValidChangelogsFromBundle(lastSeenVersion: lastSeenVersion, currentVersion: currentVersion)
        }

        let isBeta = currentVersion.preRelease != nil
        var validFiles: [ChangelogFile] = []

        // Include dev.md for beta builds
        if isBeta {
            let devURL = contents.first { $0.deletingPathExtension().lastPathComponent == Self.devFilename }
            if devURL != nil {
                validFiles.append(ChangelogFile(
                    fileVersion: SemanticVersion("999.0.0")!,
                    filename: "\(Self.devFilename).\(Self.markdownExtension)",
                    displayVersion: "Dev"
                ))
            }
        }

        for fileURL in contents {
            let filename = fileURL.lastPathComponent
            guard fileURL.pathExtension == Self.markdownExtension else { continue }
            let versionPart = fileURL.deletingPathExtension().lastPathComponent
            guard versionPart != Self.devFilename,
                  versionPart != "README" else { continue }

            guard let fileVersion = SemanticVersion(versionPart) else { continue }

            if fileVersion > lastSeenVersion && fileVersion <= currentVersion {
                validFiles.append(ChangelogFile(fileVersion: fileVersion, filename: filename))
            }
        }

        return validFiles.sorted { $0.fileVersion > $1.fileVersion }
    }

    /// Fallback approach: look for changelog files using `Bundle.main.paths`.
    private func getValidChangelogsFromBundle(lastSeenVersion: SemanticVersion, currentVersion: SemanticVersion) -> [ChangelogFile] {
        let paths = Bundle.main.paths(forResourcesOfType: Self.markdownExtension, inDirectory: nil)
        let isBeta = currentVersion.preRelease != nil
        var validFiles: [ChangelogFile] = []

        for path in paths {
            let url = URL(fileURLWithPath: path)
            let versionPart = url.deletingPathExtension().lastPathComponent

            if versionPart == Self.devFilename {
                if isBeta {
                    validFiles.append(ChangelogFile(
                        fileVersion: SemanticVersion("999.0.0")!,
                        filename: url.lastPathComponent,
                        displayVersion: "Dev"
                    ))
                }
                continue
            }

            guard versionPart != "README" && versionPart != "CHANGELOG_GUIDE" else { continue }
            guard let fileVersion = SemanticVersion(versionPart) else { continue }

            if fileVersion > lastSeenVersion && fileVersion <= currentVersion {
                validFiles.append(ChangelogFile(fileVersion: fileVersion, filename: url.lastPathComponent))
            }
        }

        return validFiles.sorted { $0.fileVersion > $1.fileVersion }
    }

    private func buildChangelogContent(_ validChangelogs: [ChangelogFile]) -> String {
        var parts: [String] = []

        for changelogFile in validChangelogs {
            guard let content = readChangelogFile(changelogFile.filename) else { continue }

            let versionHeader = "# " + String(localized: "Version \(changelogFile.displayVersion)")
            // Add extra spacing before sub-headers for readability
            let spacedContent = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(
                    of: "(?m)^(#{1,6} )",
                    with: "\n$1",
                    options: .regularExpression
                )

            parts.append("\(versionHeader)\n\n\(spacedContent)")
        }

        return parts.joined(separator: "\n\n---\n\n")
    }

    private func readChangelogFile(_ filename: String) -> String? {
        // Try reading from the Changelog subdirectory, fallback to main bundle
        let path = Bundle.main.path(
            forResource: (filename as NSString).deletingPathExtension,
            ofType: Self.markdownExtension,
            inDirectory: Self.changelogDirectory
        ) ?? Bundle.main.path(
            forResource: (filename as NSString).deletingPathExtension,
            ofType: Self.markdownExtension
        )

        if let path = path {
            do {
                return try String(contentsOfFile: path, encoding: .utf8)
            } catch {
                Self.logger.error("Failed to read changelog file \(filename): \(error.localizedDescription)")
            }
        }
        return nil
    }

    // MARK: - Types

    private struct ChangelogFile {
        let fileVersion: SemanticVersion
        let filename: String
        let displayVersion: String

        init(fileVersion: SemanticVersion, filename: String, displayVersion: String? = nil) {
            self.fileVersion = fileVersion
            self.filename = filename
            self.displayVersion = displayVersion ?? "\(fileVersion.major).\(fileVersion.minor).\(fileVersion.patch)"
        }
    }
}
