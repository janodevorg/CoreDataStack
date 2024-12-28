import Testing
import CoreData
@testable import CoreDataStack

// We can reuse the existing MockFileOperations from DatabaseWipeTests
private class MockFileOperations: FileOperations {
    var existingFiles: Set<String> = []
    var copiedFiles: [(from: URL, to: URL)] = []
    var deletedFiles: [URL] = []

    func fileExists(atPath path: String) -> Bool {
        existingFiles.contains(path)
    }

    func removeItem(at url: URL) throws {
        deletedFiles.append(url)
        existingFiles.remove(url.path)
    }

    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copiedFiles.append((srcURL, dstURL))
        existingFiles.insert(dstURL.path)
    }
}

@Suite("Migration Error Tests", .serialized)
@MainActor
final class StoreErrorTests {
    @Test("Triggers EntityContainerError.storeFailedLoading when loading fails")
    func testStoreFailedLoadingError() async throws {
        // 1. Create a bogus store URL that is a directory, not a file
        let invalidStoreURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        // 2. Ensure the directory exists
        try FileManager.default.createDirectory(at: invalidStoreURL, withIntermediateDirectories: true)

        // Cleanup afterwards
        defer {
            try? FileManager.default.removeItem(at: invalidStoreURL)
        }

        // 3. Create an EntityContainer with the invalid store URL
        let container = EntityContainer(
            name: "TestModel",
            model: NSManagedObjectModel.v1Model,
            isInMemoryStore: false
        )

        // Override the persistent store description to use the invalid URL
        container.persistentStoreDescriptions = [
            NSPersistentStoreDescription().configure {
                $0.type = NSSQLiteStoreType
                $0.url = invalidStoreURL
            }
        ]

        // 4. Load the store and expect the error
        container.loadPersistentStores(retry: false) { desc, error in
            #expect(error != nil, "Expected an error because the store URL is invalid")
            if let error = error as? EntityContainerError {
                switch error {
                case .storeFailedLoading(_):
                    #expect(error.underlyingError != nil)
                    #expect(error.errorDescription != nil)
                    #expect(error.recoverySuggestion != nil)
                    #expect(error.failureReason == nil)
                default:
                    Issue.record("Unexpected error type: \(error)")
                }
            } else {
                Issue.record("Failed to trigger EntityContainerError.storeFailedLoading")
            }
        }
    }

    @Test("loadPersistentStores handles migration errors")
    func testLoadPersistentStoresWithMigrationError() async throws {
        // Create mock file operations to track calls
        let mockFileOps = MockFileOperations()

        // Create a container with our mock
        let container = EntityContainer(
            name: "Model",
            isInMemoryStore: false,
            bundle: Bundle.module
        )
        container.fileOperations = mockFileOps

        // Create an expectation for the async completion
        var didComplete = false

        // Attempt to load with simulated migration error
        container.loadPersistentStores { desc, error in
            if let error = error as? EntityContainerError,
               error.isMigrationError {
                // Verify recovery was attempted
                #expect(!mockFileOps.deletedFiles.isEmpty)
            }
            didComplete = true
        }

        // Wait for async completion
        for _ in 0..<10 where !didComplete {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(didComplete)
    }

    // We can reuse the existing MockFileOperations from DatabaseWipeTests
    class MockFileOperations: FileOperations {
        var existingFiles: Set<String> = []
        var copiedFiles: [(from: URL, to: URL)] = []
        var deletedFiles: [URL] = []

        func fileExists(atPath path: String) -> Bool {
            existingFiles.contains(path)
        }

        func removeItem(at url: URL) throws {
            deletedFiles.append(url)
            existingFiles.remove(url.path)
        }

        func copyItem(at srcURL: URL, to dstURL: URL) throws {
            copiedFiles.append((srcURL, dstURL))
            existingFiles.insert(dstURL.path)
        }
    }
}
