import Foundation

/// A structural representation of semantic versions to allow robust comparison.
struct SemanticVersion: Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    let preRelease: String?

    init?(_ versionString: String) {
        var v = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.lowercased().hasPrefix("v") {
            v = String(v.dropFirst())
        }
        
        let parts = v.split(separator: "-", maxSplits: 1)
        guard !parts.isEmpty else { return nil }
        
        let versionParts = parts[0].split(separator: ".")
        
        guard versionParts.count >= 2,
              let major = Int(versionParts[0]),
              let minor = Int(versionParts[1]) else {
            return nil
        }
        
        self.major = major
        self.minor = minor
        self.patch = versionParts.count > 2 ? (Int(versionParts[2]) ?? 0) : 0
        self.preRelease = parts.count > 1 ? String(parts[1]) : nil
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        
        // Pre-releases are strictly less than stable releases
        if let lhsPre = lhs.preRelease, let rhsPre = rhs.preRelease {
            // Further comparison logic for pre-releases, e.g. b1 < b2
            // Simple string comparison is sufficient for WLED versions
            return lhsPre < rhsPre
        }
        if lhs.preRelease != nil && rhs.preRelease == nil {
            return true  // left is pre-release, right is stable (so left < right)
        }
        if lhs.preRelease == nil && rhs.preRelease != nil {
            return false // left is stable, right is pre-release (so left > right)
        }
        
        return false // Exactly equal
    }
    
    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.preRelease == rhs.preRelease
    }
}
