import CoreData

/**
 Defines model objects that can be persisted.

 Any conforming object that you wish to map should provide the type of the associated managed
 object, and the function that maps this object to the equivalent managed object.
 */
public protocol Persistable {
    associatedtype MO: NSManagedObject
    func mapPersistable(context: NSManagedObjectContext) -> MO
}
