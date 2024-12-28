import Testing
import CoreData
@testable import CoreDataStack

enum ContainerTestCaseError: Error {
    case failedInitialDelete
}

/// Base class for tests that initialize a container.
@MainActor
class ContainerTestCase {
    var container: EntityContainer!
    var context: NSManagedObjectContext!

    /// Because of the default parameter, this will be invoked as default initializer init().
    init(isInMemoryStore: Bool = true) async throws {
        container = try await createContainer(isInMemoryStore: isInMemoryStore)
        context = container.context

        // Delete in reverse order of dependencies
        try container.deleteAll(.all, type: DogMO.self)
        try container.deleteAll(.all, type: PersonMO.self)
        try container.context.save()

        // Add verification with counts
        let dogsCount = try container.count(.all, type: DogMO.self)
        let personsCount = try container.count(.all, type: PersonMO.self)
        print("After init cleanup - Dogs: \(dogsCount), Persons: \(personsCount)")
    }

    func createContainer(isInMemoryStore: Bool) async throws -> EntityContainer {
        // Unique name to prevent multiple suites running on the same database when isInMemoryStore = true.
        let className = String(describing: self)
        let uniqueName = "Model-\(className)-\(UUID().uuidString)"

        let container = EntityContainer(name: "Model", isInMemoryStore: isInMemoryStore, bundle: Bundle.module)

        // Override the default SQLite URL to use our unique name
        container.persistentStoreDescriptions.first?.url = NSPersistentContainer
            .defaultDirectoryURL()
            .appendingPathComponent("\(uniqueName).sqlite")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return container
    }
}
