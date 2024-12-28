import Testing
import CoreData
@testable import CoreDataStack

extension DogMO: DomainConvertible {
    public func toDomain() throws -> Dog {
        guard let id = id, let name = name else {
            throw EntityContainerError.invalidObjectDuringMapping(String(describing: self))
        }
        // Instead owner: Person, we are converting to ownerId: UUID to avoid an infinite loop
        return Dog(
            id: id,
            name: name,
            ownerId: owner?.id
        )
    }
}
