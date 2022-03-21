import CoreData

extension DogMO
{
    convenience init?(model: Dog?, context: NSManagedObjectContext) {
        guard let model = model else { return nil }
        self.init(model: model, context: context)
    }

    convenience init(model: Dog, context: NSManagedObjectContext) {
        self.init(using: context)
        id = model.id
        name = model.name
    }
}
