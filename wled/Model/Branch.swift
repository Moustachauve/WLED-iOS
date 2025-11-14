
import Foundation

enum Branch: String {
    case unknown = ""
    case beta = "beta"
    case stable = "stable"
}

extension Device {
    var branchValue: Branch {
        get {
            guard let branch = self.branch else { return .unknown }
            return Branch(rawValue: String(branch)) ?? .unknown
        }
        set {
            self.branch = String(newValue.rawValue)
        }
    }
}
