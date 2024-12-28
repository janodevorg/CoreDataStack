import Foundation

/// The only error thrown by this persistence stack.
public enum EntityContainerError: Error, Equatable {
    case invalidObjectDuringMapping(String)

    /// Store failed to load.
    case storeFailedLoading(NSError)

    /// Unexpected failure to find an object that should be in the database.
    /// This is commonly used to return non optional objects by UUID.
    case fetchRequiredFailed

    /// Any other error.
    case other(NSError)

    /// - Returns: the wrapped NSError.
    public var underlyingError: NSError? {
        switch self {
        case .invalidObjectDuringMapping: return nil
        case .fetchRequiredFailed: return nil
        case .storeFailedLoading(let error): return error
        case .other(let error): return error
        }
    }

    /// - Returns: true if this is a migration error.
    public var isMigrationError: Bool {
        underlyingError?.isMigrationError ?? false
    }

    public var errorDescription: String? {
        switch self {
        case .invalidObjectDuringMapping(let string):
            return "Invalid object during mapping: \(string)"
        case .fetchRequiredFailed:
            return "Unexpected failure to find an object that should be in the database."
        case .other(let error):
            return "Database error: \(error.localizedDescription)"
        case .storeFailedLoading(let error):
            return "Failed to load the data store: \(error.localizedDescription)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidObjectDuringMapping:
            return "The object contains invalid properties."
        case .fetchRequiredFailed:
            return "Unexpected failure to find an object that should be in the database."
        case .other(let error):
            return error.localizedFailureReason
        case .storeFailedLoading(let error):
            return error.localizedFailureReason
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidObjectDuringMapping:
            return nil
        case .fetchRequiredFailed:
            return nil
        case .other:
            return "Please try the operation again."
        case .storeFailedLoading:
            return "Try restarting the application."
        }
    }

    public static func == (lhs: EntityContainerError, rhs: EntityContainerError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidObjectDuringMapping, .invalidObjectDuringMapping):
            return true
        case (.fetchRequiredFailed, .fetchRequiredFailed):
            return true
        case (.storeFailedLoading, .storeFailedLoading):
            return true
        case (.other, .other):
            return true
        default:
            return false
        }
    }
}

public extension Error {
    var isMigrationError: Bool {
        let nsError = self as NSError

        let migrationErrorCodes = [
            134100, // NSPersistentStoreIncompatibleVersionHashError
            134110, // NSMigrationError
            134111, // NSMigrationConstraintViolationError
            134120, // NSMigrationCancelledError
            134130, // NSMigrationMissingSourceModelError
            134140, // NSMigrationMissingMappingModelError
            134150, // NSMigrationManagerSourceStoreError
            134160, // NSMigrationManagerDestinationStoreError
            134170  // NSEntityMigrationPolicyError
        ]

        return nsError.domain == "NSCocoaErrorDomain" && migrationErrorCodes.contains(nsError.code)
    }
}
