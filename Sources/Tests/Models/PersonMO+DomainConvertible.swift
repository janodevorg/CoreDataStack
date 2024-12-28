import Testing
import CoreData
@testable import CoreDataStack

extension PersonMO: DomainConvertible {
    struct Update {
        let id: UUID
        var name: String?
        var age: Int16?
        var dogs: [Dog]?
    }
    
    public func toDomain() throws -> Person {
        guard let id = id, let name = name else {
            throw EntityContainerError.invalidObjectDuringMapping(String(describing: self))
        }

        // Convert dogs relationship if present
        var domainDogs: [Dog] = []
        if let dogs = dogs as? Set<DogMO> {
            domainDogs = try dogs.map { try $0.toDomain() }
        }

        return Person(
            age: age,
            dogs: domainDogs,
            id: id,
            name: name
        )
    }
}
