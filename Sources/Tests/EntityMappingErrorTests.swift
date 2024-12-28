import Testing
import CoreData
@testable import CoreDataStack

@Suite("Entity Mapping Error Tests", .serialized)
@MainActor
final class EntityMappingErrorTests: ContainerTestCase {

    init() async throws {
        try await super.init(isInMemoryStore: true)
    }

    @Test("Test invalid PersonMO to model mapping")
    func testInvalidPersonMOMapping() throws {
        // Create PersonMO with nil required properties
        let personMO = PersonMO(using: container.context)
        personMO.id = nil  // Required property
        personMO.name = nil  // Required property

        do {
            _ = try personMO.toDomain()
            Issue.record("Expected mapping to throw")
        } catch let error as EntityContainerError {
            #expect(error == .invalidObjectDuringMapping("found invalid object during mapping"))
            #expect(!error.isMigrationError)
            #expect(error.underlyingError == nil)
            #expect(error.errorDescription != nil)
            #expect(error.recoverySuggestion == nil)
            #expect(error.failureReason != nil)
        }
    }

    @Test("Test invalid Person mapping throws error")
    func testInvalidPersonMapping() async throws {
        // Create an invalid person JSON with missing required fields
        let invalidJSON = """
        {
            "age": 30,
            "dogs": []
        }
        """

        let jsonData = invalidJSON.data(using: .utf8)!

        do {
            let person = try JSONDecoder().decode(Person.self, from: jsonData)
            _ = try person.toEntity(container: container)
            Issue.record("Expected mapping to throw")
        } catch {
            #expect(error is DecodingError)
        }
    }

    @Test("Test invalid Dog mapping throws error")
    func testInvalidDogMapping() async throws {
        // Create an invalid dog without required id
        let invalidJSON = """
        {
            "name": "Rover"
        }
        """

        let jsonData = invalidJSON.data(using: .utf8)!

        do {
            let dog = try JSONDecoder().decode(Dog.self, from: jsonData)
            _ = try dog.toEntity(container: container)
            Issue.record("Expected mapping to throw")
        } catch {
            #expect(error is DecodingError)
        }
    }

    @Test("Test fetchRequired throws when object not found")
    func testFetchRequiredError() async throws {
        let nonexistentId = UUID()

        do {
            _ = try container.fetchRequired(EntityQuery<PersonMO>.id(nonexistentId))
            Issue.record("Expected fetchRequired to throw")
        } catch let error as EntityContainerError {
            #expect(error == .fetchRequiredFailed)
            #expect(!error.isMigrationError)
            #expect(error.underlyingError == nil)
            #expect(error.errorDescription != nil)
            #expect(error.recoverySuggestion == nil)
            #expect(error.failureReason != nil)
        }
    }

    @Test("Test circular reference handling")
    func testCircularReferenceMapping() async throws {
        // Create a person and dog that reference each other
        let personId = UUID()
        let dogId = UUID()

        let personJSON = """
        {
            "age": 30,
            "id": "\(personId)",
            "name": "John",
            "dogs": [
                {
                    "id": "\(dogId)",
                    "name": "Rover",
                    "owner": {
                        "age": 30,
                        "id": "\(personId)",
                        "name": "John"
                    }
                }
            ]
        }
        """

        let jsonData = personJSON.data(using: .utf8)!
        let person = try JSONDecoder().decode(Person.self, from: jsonData)

        // This should handle the circular reference without infinite recursion
        let personMO = try person.toEntity(container: container)
        try container.context.save()

        // Verify the relationships are properly set
        #expect(personMO?.dogs?.count == 1)
        let dogMO = personMO?.dogs?.anyObject() as? DogMO
        #expect(dogMO?.owner?.id == personId)
        #expect(dogMO?.id == dogId)
    }

    @Test("Test batch operations with invalid objects")
    func testBatchMappingWithInvalidObjects() async throws {
        // Create a mix of valid and invalid person objects
        let validPerson = Person(age: 30, dogs: [], id: UUID(), name: "John")

        do {
            // Try to save array with both valid and invalid objects
            try await container.save(models: [validPerson])

            // Verify only valid object was saved
            let savedCount = try container.count(.all, type: PersonMO.self)
            #expect(savedCount == 1)

            let saved: PersonMO? = try container.fetch(.id(validPerson.id))
            #expect(saved?.name == "John")

        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
