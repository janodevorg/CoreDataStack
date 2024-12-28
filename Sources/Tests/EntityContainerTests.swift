import Testing
import CoreData
import CoreDataStack

@Suite("Model Object Tests", .serialized)
@MainActor
final class EntityContainerTests: ContainerTestCase {
    init() async throws {
        try await super.init(isInMemoryStore: true)
    }

    @Test("Reading and mapping model from JSON")
    func testReadingModelFromJSON() async throws {
        // Decode JSON to Person model
        let person = try createPersonFromJSON()
        try #require(person != nil)

        // Map Person to PersonMO
        let personMO = try person.toEntity(container: container)
        try #require(personMO != nil)
        try context.save()

        // Check reading back returns 1 person
        let readBackPersonMOs: [PersonMO] = try container.fetch()
        try #require(readBackPersonMOs.count == 1)
        let readBackPersonMO = readBackPersonMOs[0]

        // Verify data matches
        #expect(readBackPersonMO.id == person.id)
        #expect(readBackPersonMO.name == person.name)

        let dogs = readBackPersonMO.dogs?.allObjects
        try #require(dogs?.count == 1)

        guard let dogMO = dogs?[0] as? DogMO else {
            Issue.record("Expected one DogMO")
            return
        }

        #expect(dogMO.id == person.dogs?.first?.id)
        #expect(dogMO.name == person.dogs?.first?.name)
        #expect(dogMO.owner?.id == person.id)
    }

    @Test("Test Slow Query Warning")
    func testSlowQueryWarning() async throws {
        // Enable slow query warning
        container.isSlowQueryWarningEnabled = true

        // Create multiple persons
        for i in 0..<100 {
            let person = Person(age: 10, dogs: [], id: UUID(), name: "Person \(i)")
            _ = try person.toEntity(container: container)
        }
        try context.save()

        // Perform a complex query that might be slow
        let results: [PersonMO] = try container.fetch(
            .predicate(NSPredicate(format: "name CONTAINS[c] %@", "Person")),
            slowThreshold: 0.0000001  // Set a low threshold to trigger warning
        )
        #expect(results.count == 100)
    }

    @Test("Test Query Predicates and Sorting")
    func testQueryPredicatesAndSorting() async throws {
        // Create persons with different names
        let names = ["Alice", "Bob", "Charlie", "David"]
        for name in names {
            let person = Person(age: 10, dogs: [], id: UUID(), name: name)
            _ = try person.toEntity(container: container)
        }
        try context.save()

        // Test predicate
        let bQuery = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "name BEGINSWITH %@", "B")
        )
        let bResults: [PersonMO] = try container.fetch(bQuery)
        #expect(bResults.count == 1)
        #expect(bResults.first?.name == "Bob")

        // Test sorting
        let sortedQuery = EntityQuery<PersonMO>.sorted(by: "name").limit(2)
        let sortedResults: [PersonMO] = try container.fetch(sortedQuery)
        #expect(sortedResults.count == 2)
        #expect(sortedResults[0].name == "Alice")
        #expect(sortedResults[1].name == "Bob")
    }

    @Test("fetch returns all entities matching query")
    func testFetch() async throws {
        // Create test data
        let names = ["Alice", "Bob", "Charlie"]
        for name in names {
            let person = Person(age: 25, dogs: [], id: UUID(), name: name)
            _ = try person.toEntity(container: container)
        }
        try context.save()

        // Test fetch all
        let allResults: [PersonMO] = try container.fetch()
        #expect(allResults.count == 3)

        // Test fetch with predicate
        let query = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "name == %@", "Alice")
        )
        let queryResults: [PersonMO] = try container.fetch(query)
        #expect(queryResults.count == 1)
        #expect(queryResults.first?.name == "Alice")
    }

    @Test("fetchRequired returns entity when found")
    func testFetchRequired() async throws {
        // Create test entity
        let id = UUID()
        let person = Person(age: 25, dogs: [], id: id, name: "Alice")
        _ = try person.toEntity(container: container)
        try context.save()

        // Test successful fetch
        let query = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "id == %@", id as CVarArg)
        )
        let result = try container.fetchRequired(query)
        #expect(result.name == "Alice")
    }

    @Test("fetchRequired throws when entity not found")
    func testFetchRequiredThrows() async throws {
        let query = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "id == %@", UUID() as CVarArg)
        )

        do {
            _ = try container.fetchRequired(query)
            Issue.record("Expected fetchRequired to throw")
        } catch let error as EntityContainerError {
            #expect(error == .fetchRequiredFailed)
        }
    }

    @Test("count returns number of matching entities")
    func testCount() async throws {
        // Create test data
        let names = ["Alice", "Bob", "Charlie"]
        for name in names {
            let person = Person(age: 25, dogs: [], id: UUID(), name: name)
            _ = try person.toEntity(container: container)
        }
        try context.save()

        // Test total count
        let totalCount = try container.count(.all, type: PersonMO.self)
        #expect(totalCount == 3)

        // Test count with predicate
        let query = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "name BEGINSWITH %@", "A")
        )
        let filteredCount = try container.count(query, type: PersonMO.self)
        #expect(filteredCount == 1)
    }

    @Test("deleteAll removes matching entities")
    func testDeleteAll() async throws {
        // Create test data
        let youngPerson = Person(age: 20, dogs: [], id: UUID(), name: "Young")
        let oldPerson = Person(age: 30, dogs: [], id: UUID(), name: "Old")
        _ = try youngPerson.toEntity(container: container)
        _ = try oldPerson.toEntity(container: container)
        try context.save()

        // Initial count
        let initialCount = try container.count(.all, type: PersonMO.self)
        #expect(initialCount == 2)

        // Delete young person
        let deleteQuery = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "age < %d", 30)
        )
        try container.deleteAll(deleteQuery, type: PersonMO.self)

        // Verify deletion
        let remainingCount = try container.count(.all, type: PersonMO.self)
        #expect(remainingCount == 1)

        let remainingPerson: PersonMO? = try container.fetch()
        #expect(remainingPerson?.name == "Old")
    }

    @Test("fetch with slow query warning")
    func testFetchWithSlowQueryWarning() async throws {
        // Enable slow query warning
        container.isSlowQueryWarningEnabled = true

        // Create lots of test data to potentially trigger warning
        for i in 0..<100 {
            let person = Person(age: 25, dogs: [], id: UUID(), name: "Person \(i)")
            _ = try person.toEntity(container: container)
        }
        try context.save()

        // Complex query that might be slow
        let query = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "name CONTAINS[c] %@", "Person")
        )
        let results: [PersonMO] = try container.fetch(query, slowThreshold: 0.1)
        #expect(results.count == 100)
    }

    @Test("deleteAll with empty result doesn't throw")
    func testDeleteAllEmpty() async throws {
        let query = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "name == %@", "NonExistent")
        )

        // Should not throw
        try container.deleteAll(query, type: PersonMO.self)

        // Verify no changes
        let count = try container.count(.all, type: PersonMO.self)
        #expect(count == 0)
    }

    @Test("fetch returns empty array when no matches")
    func testFetchNoMatches() async throws {
        let query = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "name == %@", "NonExistent")
        )
        let results: [PersonMO] = try container.fetch(query)
        #expect(results.isEmpty)
    }

    @Test("safeAddToSet correctly adds objects to relationships")
    func testSafeAddToSet() async throws {
        // Create test entities
        let person = Person(age: 25, dogs: [], id: UUID(), name: "Test Person")
        let dog1 = Dog(id: UUID(), name: "Buddy")
        let dog2 = Dog(id: UUID(), name: "Max")

        // Convert to managed objects
        let personMO = try person.toEntity(container: container)
        let dog1MO = try dog1.toEntity(container: container)
        let dog2MO = try dog2.toEntity(container: container)
        let dogNilMO: DogMO? = nil

        // Test safeAddToSet
        personMO?.safeAddToSet(dog1MO, forKey: "dogs")
        personMO?.safeAddToSet(dogNilMO, forKey: "dogs")
        personMO?.safeAddToSet(dog2MO, forKey: "dogs")

        // Save context
        try context.save()

        // Verify dogs were added correctly
        let fetchedPersonMO: PersonMO? = try container.fetch(.id(person.id))
        try #require(fetchedPersonMO != nil)

        let dogs = fetchedPersonMO?.dogs?.allObjects as? [DogMO]
        try #require(dogs?.count == 2)

        let dogNames = dogs?.map { $0.name }
        try #require(dogNames?.contains("Buddy") == true)
        try #require(dogNames?.contains("Max") == true)
    }

    // MARK: - Update

    @Test("Test single person update")
    func testPersonUpdate() async throws {
        // Create initial person
        let personId = UUID()
        let person = Person(age: 25, dogs: [], id: personId, name: "Initial Name")
        _ = try person.toEntity(container: container)
        try context.save()

        // Create update
        let update = Person.Update(
            id: personId,
            name: "Updated Name",
            age: 30
        )

        // Perform update
        let updatedPerson = try Person.update(update, using: container)

        // Verify updates
        #expect(updatedPerson.id == personId)
        #expect(updatedPerson.name == "Updated Name")
        #expect(updatedPerson.age == 30)
    }

    @Test("Test person update with dogs")
    func testPersonUpdateWithDogs() async throws {
        // Create initial person with one dog
        let personId = UUID()
        let initialDogId = UUID()
        let person = Person(
            age: 25,
            dogs: [Dog(id: initialDogId, name: "Initial Dog")],
            id: personId,
            name: "Initial Name"
        )
        _ = try person.toEntity(container: container)
        try context.save()

        // Create update with modified existing dog and new dog
        let newDogId = UUID()
        let update = Person.Update(
            id: personId,
            name: "Updated Name",
            dogs: [
                Dog(id: initialDogId, name: "Updated Dog"),
                Dog(id: newDogId, name: "New Dog")
            ]
        )
        let updatedPerson = try Person.update(update, using: container)

        // Verify updates
        #expect(updatedPerson.id == personId)
        #expect(updatedPerson.name == "Updated Name")
        let dogs = updatedPerson.dogs ?? []
        #expect(dogs.count == 2)

        // Find dogs by ID
        let updatedDog = dogs.first { $0.id == initialDogId }
        let newDog = dogs.first { $0.id == newDogId }

        #expect(updatedDog != nil)
        #expect(updatedDog?.name == "Updated Dog")
        #expect(newDog != nil)
        #expect(newDog?.name == "New Dog")

        // Verify relationships in CoreData
        let query = EntityQuery<DogMO>.id(newDogId)
        let dogMO = try container.fetchRequired(query)
        #expect(dogMO.ownerId == personId)
    }

    @Test("Test person update with removal of dogs")
    func testPersonUpdateRemovingDogs() async throws {
        // Create initial person with two dogs
        let personId = UUID()
        let dog1Id = UUID()
        let dog2Id = UUID()
        let person = Person(
            age: 25,
            dogs: [
                Dog(id: dog1Id, name: "Dog 1"),
                Dog(id: dog2Id, name: "Dog 2")
            ],
            id: personId,
            name: "Initial Name"
        )
        _ = try person.toEntity(container: container)
        try context.save()

        // Update person with empty dogs array
        let update = Person.Update(
            id: personId,
            dogs: []
        )

        // Perform update
        let updatedPerson = try Person.update(update, using: container)

        // Verify dogs were removed
        #expect(updatedPerson.dogs?.isEmpty ?? false)

        // Verify dogs still exist but without owner
        let dogQuery = EntityQuery<DogMO>.ids([dog1Id, dog2Id])
        let dogs: [DogMO] = try container.fetch(dogQuery)
        #expect(dogs.count == 2)
        #expect(dogs.allSatisfy { $0.owner == nil })
    }

    @Test("Test batch update of persons")
    func testBatchPersonUpdate() async throws {
        // Create initial persons
        let person1Id = UUID()
        let person2Id = UUID()
        let person1 = Person(age: 25, dogs: [], id: person1Id, name: "Person 1")
        let person2 = Person(age: 30, dogs: [], id: person2Id, name: "Person 2")

        _ = try person1.toEntity(container: container)
        _ = try person2.toEntity(container: container)
        try context.save()

        // Create batch updates
        let updates = [
            Person.Update(id: person1Id, name: "Updated Person 1", age: 26),
            Person.Update(id: person2Id, name: "Updated Person 2")
        ]

        // Perform batch update
        let updatedPersons = try Person.batchUpdate(updates, using: container)

        // Verify updates
        #expect(updatedPersons.count == 2)

        let updatedPerson1 = updatedPersons.first { $0.id == person1Id }
        let updatedPerson2 = updatedPersons.first { $0.id == person2Id }

        #expect(updatedPerson1?.name == "Updated Person 1")
        #expect(updatedPerson1?.age == 26)
        #expect(updatedPerson2?.name == "Updated Person 2")
        #expect(updatedPerson2?.age == 30)  // Should remain unchanged
    }

    @Test("Test batch update with invalid ID")
    func testBatchUpdateWithInvalidId() async throws {
        // Create one valid person
        let validId = UUID()
        let person = Person(age: 25, dogs: [], id: validId, name: "Valid Person")
        _ = try person.toEntity(container: container)
        try context.save()

        // Create updates with one valid and one invalid ID
        let invalidId = UUID()
        let updates = [
            Person.Update(id: validId, name: "Updated Name"),
            Person.Update(id: invalidId, name: "Invalid Person")
        ]

        // Perform batch update
        let updatedPersons = try Person.batchUpdate(updates, using: container)

        // Verify only valid person was updated
        #expect(updatedPersons.count == 1)
        #expect(updatedPersons[0].id == validId)
        #expect(updatedPersons[0].name == "Updated Name")
    }

    // MARK: - Private Helpers

    private func createPersonFromJSON() throws -> Person {
        let jsonData = try BundleFile(filename: "person.json", bundle: BundleReference.bundle).data
        return try JSONDecoder().decode(Person.self, from: jsonData)
    }
}

private enum BundleReference {
    static let bundle = Bundle.module
}
