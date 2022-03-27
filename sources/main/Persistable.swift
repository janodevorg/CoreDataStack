import CoreData

/**
 Defines model objects that may be persisted.
 */
public protocol Persistable
{
    /// Managed object where this model will be stored.
    associatedtype MO: NSManagedObject

    /**
     Maps this instance to a managed object 'MO' that has the same properties and can be persisted.

     Note that this method has the following responsabilities:
     - Return nil if the model doesn’t satisfy the constraints of the managed object.
     - Upsert if needed. For instance, if the MO defines a unique property constraint you should
       fetch and update instead create a new one.
     - Set (or update) the MO properties with those of the model.

     - Parameter context: A managed context where this object is fetched or created.
     - Returns: A managed object with the same properties, or nil if this model is invalid.
    */
    func mapPersistable(context: NSManagedObjectContext) -> MO?
}
