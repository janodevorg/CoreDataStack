import Foundation

public enum BackupDirectory: CaseIterable, Sendable {
    case temporary
    case applicationSupport
    case documents
    case cache

    /// Returns the URL for the corresponding directory without appending "Backups".
    public var url: URL {
        switch self {
        case .temporary:
            return URL(fileURLWithPath: NSTemporaryDirectory())
        case .applicationSupport:
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        case .cache:
            return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        }
    }
}
