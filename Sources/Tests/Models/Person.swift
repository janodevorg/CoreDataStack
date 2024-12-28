import CoreData
import CoreDataStack
import Foundation

public struct Person: Codable {
    let age: Int16
    var dogs: [Dog]?
    let id: UUID
    let name: String
}

extension Person {
    struct Update {
        let id: UUID
        var name: String?
        var age: Int16?
        var dogs: [Dog]?
    }
}

extension Person: EntityConvertible {
    public func toEntity(container: EntityContainer) throws -> PersonMO? {
        let context = container.context

        // check for existing person first
        let query = EntityQuery<PersonMO>.id(id)
        let personMO = try container.fetch(query) ?? PersonMO(using: context)

        // update person properties
        personMO.id = id
        personMO.name = name
        personMO.age = age

        // handle dogs relationship
        if let modelDogs = dogs {
            let dogMOs = try modelDogs.compactMap { dog -> DogMO? in
                let existingDog: DogMO? = try container.fetch(.id(dog.id))

                if let existingDog = existingDog {
                    existingDog.name = dog.name
                    existingDog.owner = personMO
                    return existingDog
                } else {
                    let dogMO = DogMO(using: context)
                    dogMO.id = dog.id
                    dogMO.name = dog.name
                    dogMO.owner = personMO
                    return dogMO
                }
            }
            personMO.dogs = NSSet(array: dogMOs)
        }

        return personMO
    }
}

extension Person {
    /// Updates an existing Person entity with the provided changes
    static func update(_ update: Person.Update, using container: EntityContainer) throws -> Person {
        let query = EntityQuery<PersonMO>.id(update.id)
        guard let personMO = try container.fetch(query) else {
            throw EntityContainerError.fetchRequiredFailed
        }

        // Update basic fields
        if let newName = update.name {
            personMO.name = newName
        }
        if let newAge = update.age {
            personMO.age = newAge
        }

        // Handle dogs relationship if provided
        if let newDogs = update.dogs {
            // Convert current relationship to a Set for easier removal
            let currentDogs = (personMO.dogs as? Set<DogMO>) ?? []

            // 1) Remove only the dogs that are no longer in the new set
            let newDogIDs = Set(newDogs.map { $0.id })
            for oldDogMO in currentDogs {
                guard let oldDogID = oldDogMO.id else { continue }
                // If this old dog's ID isn't in the new update, remove it
                if !newDogIDs.contains(oldDogID) {
                    oldDogMO.owner = nil
                    personMO.removeFromDogs(oldDogMO)
                }
            }

            // 2) Create or update the dogs that are in the new set
            for dog in newDogs {
                // Attempt to fetch existing dog
                let dogMO: DogMO
                if let existingDogMO = try container.fetch(EntityQuery<DogMO>.id(dog.id)) {
                    dogMO = existingDogMO
                    dogMO.name = dog.name
                } else {
                    // Or create a new DogMO
                    dogMO = DogMO(using: container.context)
                    dogMO.id = dog.id
                    dogMO.name = dog.name
                }

                // Add it to the person's relationship and set its owner
                // (If it's already in the relationship, calling this again is harmless)
                personMO.addToDogs(dogMO)
                dogMO.owner = personMO
                
                print("dogMO.owner is now:", dogMO.owner ?? "nil")
                print("personMO.dogs contains:", personMO.dogs ?? "nil")
            }
        }

        try container.context.save()
        return try personMO.toDomain()
    }

    /// Updates multiple Person entities in batch
    static func batchUpdate(_ updates: [Update], using container: EntityContainer) throws -> [Person] {
        let idsToUpdate = updates.map { $0.id }
        let query = EntityQuery<PersonMO>.ids(idsToUpdate)
        let personsToUpdate: [PersonMO] = try container.fetch(query)

        let personsByID = Dictionary(uniqueKeysWithValues: try personsToUpdate.map {
            guard let id = $0.id else { throw EntityContainerError.invalidObjectDuringMapping(String(describing: $0)) }
            return (id, $0)
        })

        for update in updates {
            guard let personMO = personsByID[update.id] else {
                continue
            }

            if let newName = update.name {
                personMO.name = newName
            }

            if let newAge = update.age {
                personMO.age = newAge
            }

            if let newDogs = update.dogs {
                // First remove all existing dogs from the relationship
                personMO.dogs?.allObjects.forEach { dog in
                    guard let dogMO = dog as? DogMO else { return }
                    dogMO.owner = nil
                    personMO.removeFromDogs(dogMO)
                }

                // Create or update dogs and establish relationships
                for dog in newDogs {
                    let dogMO: DogMO
                    if let existingDog = try container.fetch(EntityQuery<DogMO>.id(dog.id)) {
                        dogMO = existingDog
                        dogMO.name = dog.name
                    } else {
                        dogMO = DogMO(using: container.context)
                        dogMO.id = dog.id
                        dogMO.name = dog.name
                    }

                    // Use CoreData's relationship management methods
                    personMO.addToDogs(dogMO)
                    dogMO.owner = personMO
                }
            }
        }

        try container.context.save()
        return try personsToUpdate.map { try $0.toDomain() }
    }
}
