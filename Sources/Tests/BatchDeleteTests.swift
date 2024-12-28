import Testing
import CoreData
import CoreDataStack

@Suite("Batch Delete Tests", .serialized)
@MainActor
final class BatchDeleteTests: ContainerTestCase {
    init() async throws {
        try await super.init(isInMemoryStore: false)
    }

    @Test("Test Batch Delete")
    func testBatchDelete() async throws {
        // Create multiple persons
        for i in 0..<5 {
            let person = Person(age: 10, dogs: [], id: UUID(), name: "Person \(i)")
            _ = try person.toEntity(container: container)
        }
        try context.save()

        // Verify initial count
        let initialCount = try container.count(.all, type: PersonMO.self)
        #expect(initialCount == 5)

        // Note: Batch delete is not supported for memory stores.
        // It will fail with "Unknown command type <NSBatchDeleteRequest..."
        try container.batchDeleteAll(.all, type: PersonMO.self)

        // Verify final count
        let finalCount = try container.count(.all, type: PersonMO.self)
        #expect(finalCount == 0)
    }
}
