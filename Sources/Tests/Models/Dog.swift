import CoreData
import CoreDataStack
import Foundation

public struct Dog: Codable {
    let id: UUID
    let name: String
    var ownerId: UUID?
}

extension Dog {
    struct Update {
        let id: UUID
        var name: String?
    }
}

extension Dog: EntityConvertible {
    public func toEntity(container: EntityContainer) throws -> DogMO? {
        let context = container.context

        let dogMO = DogMO(using: context)
        dogMO.id = id
        dogMO.name = name

        if let ownerId = ownerId {
            let existingOwner: PersonMO? = try container.fetch(.id(ownerId))

            if let existingOwner = existingOwner {
                dogMO.owner = existingOwner
                existingOwner.addToDogs(dogMO)
            }
        }

        return dogMO
    }
}
