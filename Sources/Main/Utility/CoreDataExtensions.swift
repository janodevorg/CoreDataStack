import CoreData

public extension NSManagedObject {
    /**
     Returns the default entity name for this managed object class.

     By default, this returns the class name as a string. Override this
     method if your Core Data entity name differs from the class name.

     - Returns: The name of the entity in the Core Data model
     */
    class func entityName() -> String {
        String("\(self)")
    }

    /**
     Creates a new managed object instance in the given context.

     - Parameter usedContext: The managed object context to create the instance in
     - Precondition: The entity must exist in the managed object model
     */
    convenience init(using usedContext: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        guard let entity = NSEntityDescription.entity(forEntityName: name, in: usedContext) else {
            preconditionFailure("Couldn’t find the entity \(name) in the model.")
        }
        self.init(entity: entity, insertInto: usedContext)
    }
}

public extension NSManagedObject {
    /**
     Safely adds a given managed object to a Core Data relationship set.

     This method ensures the addition is safe by checking for nil values.
     If the relationship set doesn’t exist, it automatically creates one.

     - Parameter object: The managed object to add, if not nil
     - Parameter key: The key of the relationship set
     */
    func safeAddToSet(_ object: NSManagedObject?, forKey key: String) {
        guard let object = object else { return }
        let currentSet = mutableSetValue(forKey: key)
        currentSet.add(object)
    }
}

/**
 Provides a Core Data batch delete similar to Swift Data `context.delete(matching:)`.
 Usage:
 ```
 let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
 fetchRequest.predicate = NSPredicate(format: "age > %d", 18)
 try context.delete(matching: fetchRequest)
 ```
 */
extension NSManagedObjectContext {
    func delete<T: NSManagedObject>(matching fetchRequest: NSFetchRequest<T>) throws {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        deleteRequest.resultType = .resultTypeObjectIDs

        let result = try execute(deleteRequest) as? NSBatchDeleteResult
        guard let objectIDs = result?.result as? [NSManagedObjectID] else { return }

        // sync the deletions with the context
        let changes = [NSDeletedObjectsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
    }
}
