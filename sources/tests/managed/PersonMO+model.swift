import Foundation
import CoreData

extension PersonMO
{
    convenience init?(model: Person?, context: NSManagedObjectContext) {
        guard let model = model else { return nil }
        self.init(model: model, context: context)
    }

    convenience init(model: Person, context: NSManagedObjectContext) {
        self.init(using: context)
        id = model.id
        name = model.name
        if let modelDogs: [Dog] = model.dogs {
            let dogs: [DogMO] = modelDogs.map { DogMO(model: $0, context: context) }
            dogs.forEach { $0.owner = self }
            self.dogs = NSSet(array: dogs)
        }
    }
}
