import Foundation

/**
 The only error thrown by this persistence stack.

 By wrapping all errors of a layer in a single error, you can recognize the origin of any catched
 error.
 */
public enum PersistenceError: Error {

    /// Store failed to load.
    case storeFailedLoading(NSError)

    /// Any other error.
    case other(NSError)

    /// - Returns: the wrapped NSError.
    public var underlyingError: NSError {
        switch self {
        case .storeFailedLoading(let error): return error
        case .other(let error): return error
        }
    }

    /// - Returns: true if this is a migration error.
    public var isMigrationError: Bool {
        underlyingError.isMigrationError
    }
}

private extension Error
{
    var isMigrationError: Bool {
        let nsError = self as NSError
        guard let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError else { return false }
        return underlyingError.domain == "NSCocoaErrorDomain" && underlyingError.code == 134_110
    }
}
