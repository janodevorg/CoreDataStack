import CoreData

public extension NSManagedObject
{
    /// Default name for managed objects.
    class func entityName() -> String {
        String("\(self)")
    }

    /// Creates a new instance by inserting in the given context.
    convenience init(using usedContext: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        guard let entity = NSEntityDescription.entity(forEntityName: name, in: usedContext) else {
            preconditionFailure("Couldn’t find the entity \(name) in the model.")
        }
        self.init(entity: entity, insertInto: usedContext)
    }
}
