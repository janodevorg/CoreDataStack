import CoreData

/// A generic, type-safe wrapper for creating Core Data fetch requests with flexible configuration.
public struct EntityQuery<T: NSManagedObject> {
    public let predicate: NSPredicate?
    public let sortDescriptors: [NSSortDescriptor]
    public let fetchLimit: Int?

    public init(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = [],
        fetchLimit: Int? = nil
    ) {
        self.predicate = predicate
        self.sortDescriptors = sortDescriptors
        self.fetchLimit = fetchLimit
    }

    public var fetchRequest: NSFetchRequest<T> {
        NSFetchRequest<T>(entityName: T.entityName()).configure {
            $0.predicate = predicate
            $0.sortDescriptors = sortDescriptors
            if let fetchLimit {
                $0.fetchLimit = fetchLimit
            }
        }
    }

    // MARK: - Modifiers

    private func sorting(_ keyPath: String, isAscending: Bool) -> EntityQuery<T> {
        var sorts = sortDescriptors
        sorts.append(NSSortDescriptor(key: keyPath, ascending: isAscending))
        return EntityQuery(predicate: predicate,
                           sortDescriptors: sorts,
                           fetchLimit: fetchLimit)
    }

    public func ascending(_ keyPath: String) -> EntityQuery<T> {
        sorting(keyPath, isAscending: true)
    }

    public func descending(_ keyPath: String) -> EntityQuery<T> {
        sorting(keyPath, isAscending: false)
    }

    public func and(_ predicate: NSPredicate) -> EntityQuery<T> {
        let newPredicate = self.predicate.map {
            NSCompoundPredicate(type: .and,
                              subpredicates: [$0, predicate])
        } ?? predicate
        return EntityQuery(predicate: newPredicate,
                           sortDescriptors: sortDescriptors,
                           fetchLimit: fetchLimit)
    }

    public func limit(_ count: Int) -> EntityQuery<T> {
        EntityQuery(predicate: predicate,
                    sortDescriptors: sortDescriptors,
                    fetchLimit: count)
    }
}

// MARK: - Common Queries
public extension EntityQuery {
    /// Retrieve all entities without filtering or sorting.
    static var all: EntityQuery<T> {
        EntityQuery<T>()
    }

    /// Creates a query sorted by a specific key path in ascending order.
    static func sorted(by keyPath: String) -> EntityQuery<T> {
        EntityQuery<T>(sortDescriptors: [NSSortDescriptor(key: keyPath, ascending: true)])
    }

    /// Creates a query with a specific predicate for filtering.
    static func predicate(_ predicate: NSPredicate) -> EntityQuery<T> {
        EntityQuery<T>(predicate: predicate)
    }
}

public extension EntityQuery where T: NSManagedObject & Identifiable, T.ID == UUID? {
    /// Fetches an entity by its UUID
    static func id(_ id: UUID) -> EntityQuery<T> {
        EntityQuery(predicate: NSPredicate(format: "id == %@", id as NSUUID))
    }

    /// Fetches multiple entities by their UUIDs
    static func ids(_ ids: [UUID]) -> EntityQuery<T> {
        EntityQuery(predicate: NSPredicate(format: "id IN %@", ids as NSArray))
    }
}
