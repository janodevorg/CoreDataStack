import Testing
import CoreData
@testable import CoreDataStack

@Suite("Domain Convertible Tests", .serialized)
@MainActor
final class DomainConvertibleTests: ContainerTestCase {

    // MARK: - Test Data Structures

    struct TestModel: EntityConvertible {
        let id: UUID
        let name: String

        func toEntity(container: EntityContainer) throws -> PersonMO? {
            // Check for existing entity with same ID
            let query = EntityQuery<PersonMO>.id(id)
            if let existingMO = try container.fetch(query) {
                // Update existing
                existingMO.name = name
                return existingMO
            } else {
                // Create new
                let mo = PersonMO(using: container.context)
                mo.id = id
                mo.name = name
                mo.age = 25 // default value for testing
                return mo
            }
        }
    }

    struct InvalidModel: EntityConvertible {
        func toEntity(container: EntityContainer) throws -> PersonMO? {
            // Simulates a validation failure
            return nil
        }
    }

    struct ThrowingModel: EntityConvertible {
        func toEntity(container: EntityContainer) throws -> PersonMO? {
            throw NSError(domain: "test", code: 1, userInfo: nil)
        }
    }

    // MARK: - fetchRequired Tests

    @Test("fetchRequired with DomainConvertible returns mapped domain object")
    func testFetchRequiredSuccess() async throws {
        // Setup: Create a test entity
        let person = Person(age: 30, dogs: [], id: UUID(), name: "Test Person")
        _ = try person.toEntity(container: container)
        try context.save()

        // Test: Fetch and convert to domain object
        let query = EntityQuery<PersonMO>.predicate(NSPredicate(format: "name == %@", "Test Person"))
        let fetchedPerson: Person = try container.fetchRequired(query)

        // Verify
        #expect(fetchedPerson.name == "Test Person")
        #expect(fetchedPerson.age == 30)
    }

    @Test("fetchRequired throws when entity not found")
    func testFetchRequiredNotFound() async throws {
        let query = EntityQuery<PersonMO>.predicate(NSPredicate(format: "name == %@", "Nonexistent"))

        do {
            let _: Person = try container.fetchRequired(query)
            Issue.record("Expected fetchRequired to throw")
        } catch let error as EntityContainerError {
            #expect(error == .fetchRequiredFailed)
        }
    }

    // MARK: - save Tests

    @Test("save successfully persists valid models")
    func testSaveSuccess() async throws {
        // Setup: Create test models
        let models = [
            TestModel(id: UUID(), name: "Model 1"),
            TestModel(id: UUID(), name: "Model 2")
        ]

        // Test: Save models
        try await container.save(models: models)

        // Verify: Check persisted data
        let fetchedMOs: [PersonMO] = try container.fetch()
        #expect(fetchedMOs.count == 2)

        let names = Set(fetchedMOs.map { $0.name })
        #expect(names.contains("Model 1"))
        #expect(names.contains("Model 2"))
    }

    @Test("save handles empty array")
    func testSaveEmptyArray() async throws {
        try await container.save(models: [TestModel]())

        let count = try container.count(.all, type: PersonMO.self)
        #expect(count == 0)
    }

    @Test("save skips invalid models")
    func testSaveInvalidModels() async throws {
        // Create separate arrays for each concrete type
        let validModels = [TestModel(id: UUID(), name: "Valid")]
        let invalidModels = [InvalidModel()]

        // Save each array separately
        try await container.save(models: validModels)
        try await container.save(models: invalidModels)

        // Verify: Only valid model was saved
        let fetchedMOs: [PersonMO] = try container.fetch()
        #expect(fetchedMOs.count == 1)
        #expect(fetchedMOs.first?.name == "Valid")
    }

    @Test("save throws on conversion error")
    func testSaveThrowingModel() async throws {
        do {
            try await container.save(models: [ThrowingModel()])
            Issue.record("Expected save to throw")
        } catch let error as EntityContainerError {
            #expect(error.underlyingError?.domain == "test")
            #expect(error.underlyingError?.code == 1)
        }
    }

    @Test("save handles update of existing entities")
    func testSaveUpdatesExisting() async throws {
        // Setup: Create initial model
        let id = UUID()
        let initialModel = TestModel(id: id, name: "Initial")
        try await container.save(models: [initialModel])

        // Update
        let updatedModel = TestModel(id: id, name: "Updated")
        try await container.save(models: [updatedModel])

        // Verify
        let query = EntityQuery<PersonMO>.id(id)
        let fetchedMO: PersonMO = try container.fetchRequired(query)
        #expect(fetchedMO.name == "Updated")

        // Verify only one entity exists
        let count = try container.count(.all, type: PersonMO.self)
        #expect(count == 1) // Expectation failed: (count → 2) == 1
    }
}
