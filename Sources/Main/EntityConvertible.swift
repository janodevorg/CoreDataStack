import CoreData

/// A domain object that can be converted to a Core Data object.
public protocol EntityConvertible {
    /// Managed object where this model will be stored.
    associatedtype MO: NSManagedObject

    /**
     Maps this instance to a managed object 'MO' that has the same properties and can be persisted.

     This should:
     - Return nil if the model doesn’t satisfy the constraints of the managed object.
     - Upsert if needed. For instance, if the MO defines a unique property constraint
       you should fetch and update instead create a new one.
     - Set (or update) the MO properties with those of the model.

     - Parameter container: The entity container
     - Returns: A managed object with the same properties, or nil if this model is invalid.
    */
    func toEntity(container: EntityContainer) throws -> MO?
}
