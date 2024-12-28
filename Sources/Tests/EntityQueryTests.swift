import Testing
import CoreData
@testable import CoreDataStack

@Suite("EntityQuery Tests", .serialized)
@MainActor
final class EntityQueryTests: ContainerTestCase {
    private func setupTestData() throws {
        // Create some test entities
        let _ = try [
            Person(age: 30, id: UUID(), name: "Alice"),
            Person(age: 25, id: UUID(), name: "Bob"),
            Person(age: 35, id: UUID(), name: "Charlie"),
            Person(age: 25, id: UUID(), name: "David")
        ].map { try $0.toEntity(container: container) }

        try context.save()
    }

    @Test("Test all query returns all entities")
    func testAllQuery() throws {
        try setupTestData()

        let query = EntityQuery<PersonMO>.all
        let results: [PersonMO] = try container.fetch(query)

        #expect(results.count == 4)
    }

    @Test("Test query with predicate")
    func testPredicateQuery() throws {
        try setupTestData()

        let predicate = NSPredicate(format: "age == %d", 25)
        let query = EntityQuery<PersonMO>(predicate: predicate)
        let results: [PersonMO] = try container.fetch(query)

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.age == 25 })
    }

    @Test("Test query with sort descriptors")
    func testSortDescriptors() throws {
        try setupTestData()

        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        let query = EntityQuery<PersonMO>(sortDescriptors: [sortDescriptor])
        let results: [PersonMO] = try container.fetch(query)

        #expect(results.count == 4)
        #expect(results[0].name == "Alice")
        #expect(results[1].name == "Bob")
        #expect(results[2].name == "Charlie")
        #expect(results[3].name == "David")
    }

    @Test("Test query with fetch limit")
    func testFetchLimit() throws {
        try setupTestData()

        let query = EntityQuery<PersonMO>(fetchLimit: 2)
        let results: [PersonMO] = try container.fetch(query)

        #expect(results.count == 2)
    }

    @Test("Test query with predicate and sort descriptors")
    func testPredicateAndSortDescriptors() throws {
        try setupTestData()

        let predicate = NSPredicate(format: "age == %d", 25)
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: false)
        let query = EntityQuery<PersonMO>(
            predicate: predicate,
            sortDescriptors: [sortDescriptor]
        )
        let results: [PersonMO] = try container.fetch(query)

        #expect(results.count == 2)
        #expect(results[0].name == "David")
        #expect(results[1].name == "Bob")
    }

    @Test("Test convenience method sorted(by:)")
    func testConvenienceSortedMethod() throws {
        try setupTestData()

        let results: [PersonMO] = try container.fetch(.sorted(by: "name"))

        #expect(results.count == 4)
        #expect(results[0].name == "Alice")
        #expect(results[1].name == "Bob")
        #expect(results[2].name == "Charlie")
        #expect(results[3].name == "David")
    }

    @Test("Test convenience method predicate(_:)")
    func testConveniencePredicateMethod() throws {
        try setupTestData()

        let query = EntityQuery<PersonMO>.predicate(
            NSPredicate(format: "age > %d", 30)
        )
        let results: [PersonMO] = try container.fetch(query)

        #expect(results.count == 1)
        #expect(results[0].name == "Charlie")
    }

    @Test("ascending(_:) adds ascending sort descriptor")
    func testAscendingSort() {
        let query = EntityQuery<PersonMO>.all
            .ascending("name")

        guard let sortDescriptor = query.sortDescriptors.first else {
            Issue.record("Expected sort descriptor")
            return
        }

        #expect(sortDescriptor.key == "name")
        #expect(sortDescriptor.ascending)
    }

    @Test("descending(_:) adds descending sort descriptor")
    func testDescendingSort() {
        let query = EntityQuery<PersonMO>.all
            .descending("name")

        guard let sortDescriptor = query.sortDescriptors.first else {
            Issue.record("Expected sort descriptor")
            return
        }

        #expect(sortDescriptor.key == "name")
        #expect(!sortDescriptor.ascending)
    }

    @Test("multiple sort descriptors are combined in order")
    func testMultipleSortDescriptors() {
        let query = EntityQuery<PersonMO>.all
            .ascending("lastName")
            .descending("firstName")

        #expect(query.sortDescriptors.count == 2)

        let lastNameSort = query.sortDescriptors[0]
        #expect(lastNameSort.key == "lastName")
        #expect(lastNameSort.ascending)

        let firstNameSort = query.sortDescriptors[1]
        #expect(firstNameSort.key == "firstName")
        #expect(!firstNameSort.ascending)
    }

    @Test("and(_:) combines predicates with AND")
    func testAndPredicate() {
        let initialPredicate = NSPredicate(format: "age > 18")
        let additionalPredicate = NSPredicate(format: "name CONTAINS %@", "John")

        let query = EntityQuery<PersonMO>.predicate(initialPredicate)
            .and(additionalPredicate)

        guard let compound = query.predicate as? NSCompoundPredicate else {
            Issue.record("Expected compound predicate")
            return
        }

        #expect(compound.compoundPredicateType == .and)
        #expect(compound.subpredicates.count == 2)
        #expect(compound.subpredicates[0] as? NSPredicate == initialPredicate)
        #expect(compound.subpredicates[1] as? NSPredicate == additionalPredicate)
    }

    @Test("limit(_:) sets fetch limit")
    func testLimit() {
        let query = EntityQuery<PersonMO>.all
            .limit(5)

        #expect(query.fetchLimit == 5)
    }

    @Test("id(_:) creates correct UUID predicate")
    func testQueryById() {
        let id = UUID()
        let query = EntityQuery<PersonMO>.id(id)

        guard let predicate = query.predicate else {
            Issue.record("Expected predicate")
            return
        }

        #expect(predicate.predicateFormat == "id == \(id)")
    }

    @Test("ids(_:) creates correct IN predicate")
    func testQueryByIds() {
        let ids = [UUID(), UUID(), UUID()]
        let query = EntityQuery<PersonMO>.ids(ids)

        guard let predicate = query.predicate else {
            Issue.record("Expected predicate")
            return
        }

        #expect(predicate.predicateFormat == "id IN {\(ids.map { $0.description }.joined(separator: ", "))}")
    }

    @Test("chained query builds correct combined query")
    func testChainedQuery() {
        let age = 21
        let limit = 10

        let query = EntityQuery<PersonMO>.all
            .ascending("lastName")
            .descending("firstName")
            .and(NSPredicate(format: "age > %d", age))
            .limit(limit)

        // Verify sort descriptors
        #expect(query.sortDescriptors.count == 2)
        #expect(query.sortDescriptors[0].key == "lastName")
        #expect(query.sortDescriptors[0].ascending)
        #expect(query.sortDescriptors[1].key == "firstName")
        #expect(!query.sortDescriptors[1].ascending)

        // Verify predicate
        guard let predicate = query.predicate else {
            Issue.record("Expected predicate")
            return
        }
        #expect(predicate.predicateFormat == "age > \(age)")

        // Verify limit
        #expect(query.fetchLimit == limit)
    }
}
