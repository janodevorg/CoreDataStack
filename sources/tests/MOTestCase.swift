import CoreData
import CoreDataStack
import struct Kit.BundleFile
import XCTest

final class MOTestCase: XCTestCase
{
    var container: PersistentContainer!
    var context: NSManagedObjectContext!

    override func setUp() {
        self.container = createContainer()
        self.context = container.newBackgroundContext()
        super.setUp()
    }

    // MARK: - Private

    private func createContainer() -> PersistentContainer {
        let exp = expectation(description: "load stores")
        let container = PersistentContainer(name: "Model", inMemory: true, bundle: Bundle.module)
        container.loadPersistentStores { desc, error in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
        return container
    }

    func testReadingModelFromJSON() async throws
    {
        // decode JSON to Person model
        let person = try createPersonFromJSON()
        XCTAssertNotNil(person)

        // map Person to PersonMO
        let personMO = person.mapPersistable(context: context)
        XCTAssertNotNil(personMO)

        // nothing saved yet
        let savedPersons: [PersonMO] = try await container.read()
        XCTAssertEqual(savedPersons.count, 0)

        try context.save()

        // check reading back returns 1 person
        let readBackPersonMOs: [PersonMO] = try await container.read()
        guard let readBackPersonMO = readBackPersonMOs.first, readBackPersonMOs.count == 1 else {
            XCTFail("One person expected")
            return
        }

        // check matching data
        XCTAssertEqual(readBackPersonMO.id, person.id)
        XCTAssertEqual(readBackPersonMO.name, person.name)
        XCTAssertEqual(readBackPersonMO.dogs?.allObjects.count, 1)
        guard let dogMO = readBackPersonMO.dogs?.allObjects.first as? DogMO else {
            XCTFail("Expected one dog")
            return
        }
        XCTAssertEqual(dogMO.id, person.dogs?.first?.id)
        XCTAssertEqual(dogMO.name, person.dogs?.first?.name)
        XCTAssertEqual(dogMO.owner?.id, person.id)
    }

    // MARK: - Private

    private func createModel() -> Person {
        var alice = Person(id: 1, name: "alice", dogs: nil)
        let oreo = Dog(id: 1, name: "Oreo", owner: alice)
        alice.dogs = [oreo]
        return alice
    }

    private func createJSON(person: Person) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let encodedJSON: Data = try! encoder.encode(person)
        return String(data: encodedJSON, encoding: .utf8)!
    }

    private func createPersonFromJSON() throws -> Person {
        let jsonData = try BundleFile(filename: "person.json", bundle: BundleReference.bundle).data
        return try! JSONDecoder().decode(Person.self, from: jsonData)
    }
}

private enum BundleReference {
    static let bundle = Bundle.module
}
