
/// An entity (object from the persistence layer) that can be converted to a domain object.
public protocol DomainConvertible {
    /// The domain model type for this managed object.
    associatedtype DomainModel

    /// Converts the managed object to a domain model.
    func toDomain() throws -> DomainModel
}
