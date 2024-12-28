import Testing
import CoreData
@testable import CoreDataStack

@Suite("Programmatic Model Migration Tests", .serialized)
final class ProgrammaticModelTests {
    /// Creates a v2 model with incompatible changes
    func createV2Model() -> NSManagedObjectModel {
        let model = NSManagedObjectModel.v1Model

        // Add a required email attribute (incompatible change)
        guard let personEntity = model.entitiesByName["Person"] else {
            preconditionFailure("Person entity not found")
        }

        let emailAttr = NSAttributeDescription()
        emailAttr.name = "email"
        emailAttr.attributeType = .stringAttributeType
        emailAttr.isOptional = false  // Required field with no default value

        personEntity.properties = personEntity.properties + [emailAttr]

        return model
    }

    /// Creates a store with the v1 schema and some test data
    func createStoreWithV1Schema(at url: URL) throws {
        // 1. Create coordinator with v1 model
        let v1Model = NSManagedObjectModel.v1Model
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1Model)

        // 2. Add store
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: nil
        )

        // 3. Create context and add some data
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        // 4. Insert test data
        let person = NSEntityDescription.insertNewObject(
            forEntityName: "Person",
            into: context
        )
        person.setValue("John", forKey: "name")
        person.setValue(30, forKey: "age")
        person.setValue(UUID(), forKey: "id")

        // 5. Save to create the store file
        try context.save()
    }

    @Test("Test programmatic migration error")
    func testProgrammaticMigrationError() async throws {
        // 1. Create temporary store URL
        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        // 2. Create store with v1 schema
        try createStoreWithV1Schema(at: storeURL)

        defer {
            // Cleanup
            try? FileManager.default.removeItem(at: storeURL)
        }

        // 3. Try to open with v2 schema
        let v2Model = createV2Model()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: v2Model)

        do {
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: nil
            )
            Issue.record("Expected migration error")
        } catch {
            #expect(error.isMigrationError)
        }
    }

    @Test("Test multiple incompatible changes")
    func testMultipleIncompatibleChanges() {
        // Create v1 model
        let v1 = NSManagedObjectModel.v1Model

        // Create v2 with multiple incompatible changes
        let v2 = createV2Model()
        guard let person = v2.entitiesByName["Person"] else {
            Issue.record("Person entity not found")
            return
        }

        // Change age type from Int16 to String (incompatible)
        if let ageAttr = person.attributesByName["age"] {
            ageAttr.attributeType = .stringAttributeType
        }

        // Add required relationship (incompatible)
        let addressEntity = NSEntityDescription()
        addressEntity.name = "Address"
        addressEntity.managedObjectClassName = "AddressMO"

        let streetAttr = NSAttributeDescription()
        streetAttr.name = "street"
        streetAttr.attributeType = .stringAttributeType
        streetAttr.isOptional = false

        addressEntity.properties = [streetAttr]

        let addressRelation = NSRelationshipDescription()
        addressRelation.name = "address"
        addressRelation.destinationEntity = addressEntity
        addressRelation.isOptional = false // Required relationship

        let personRelation = NSRelationshipDescription()
        personRelation.name = "person"
        personRelation.destinationEntity = person

        addressRelation.inverseRelationship = personRelation
        personRelation.inverseRelationship = addressRelation

        person.properties = person.properties + [addressRelation]
        addressEntity.properties = addressEntity.properties + [personRelation]

        v2.entities = v2.entities + [addressEntity]

        // Verify models are incompatible
        #expect(!v1.isConfiguration(withName: nil, compatibleWithStoreMetadata: [:]))
        #expect(!v2.isConfiguration(withName: nil, compatibleWithStoreMetadata: [:]))
    }

    @Test("Forces a migration error using the new init")
    func testMigrationErrorWithCustomModelInit() async throws {
        // 1) Pick a place to write the v1 store file
        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        // 2) Create the v1 store on disk
        try createStoreWithV1Schema(at: storeURL)

        // 3) Clean up afterwards
        defer {
            try? FileManager.default.removeItem(at: storeURL)
        }

        // 4) Build the v2 model, which is incompatible (requires 'email')
        let v2Model = createV2Model()

        // 5) Create an EntityContainer with your custom init, passing v2Model
        let container = EntityContainer(
            name: "TestModel",
            model: v2Model,           // <— Key difference: we inject the model directly
            isInMemoryStore: false
        )

        // 6) Point the container at the same SQLite file
        container.persistentStoreDescriptions = [
            NSPersistentStoreDescription().configure {
                $0.type = NSSQLiteStoreType
                $0.url = storeURL
            }
        ]

        // 7) Attempt to load with `retry: false` expecting a migration error
        container.loadPersistentStores(retry: false) { desc, error in
            #expect(error != nil, "Expected a migration error because we have a v2 model with a required 'email' attribute.")
            if let error {
                #expect(error.isMigrationError, "Expected the error to be recognized as a migration error.")
            }
        }
    }
}
