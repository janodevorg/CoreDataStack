import CoreData
import Foundation
import os

public class PersistentContainer: NSPersistentContainer
{
    private let log = Logger(subsystem: "dev.jano", category: "persistence")

    // Name of the .xcdatamodeld directory, minus the extension.
    private let modelName: String

    // Persistence store description in memory.
    private lazy var inMemoryStoreDescription = NSPersistentStoreDescription().configure {
        $0.type = NSInMemoryStoreType
        $0.url = URL(fileURLWithPath: "/dev/null")
        $0.shouldAddStoreAsynchronously = false
    }

    // Persistence store description in SQLite.
    private lazy var sqliteStoreDescription = NSPersistentStoreDescription().configure {
        $0.url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("\(modelName).sqlite")
        $0.shouldAddStoreAsynchronously = false
        $0.type = NSSQLiteStoreType
    }

    /// Remove the existing database.
    public func wipeSQLDatabase() {
        log.info("Removing existing database.")
        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("\(modelName).sqlite")
        try? FileManager.default.removeItem(at: url)
    }

    /**
     Creates a persistence container.

     A note about testing: if the model is inside a package, in order to test it you will have to
     expose the `Bundle.module` with a reference from a class inside that package. e.g.
     ```
     public enum BundleReference {
         public static let bundle = Bundle.module
     }
     ```
     See https://stackoverflow.com/questions/58258965/71298555#71298555 for details.

     - Parameters:
       - name: Name of the .xcdatamodeld directory containg your model, without the `.xcdatamodeld` extension.
       - inMemory: True to create a store in memory that won’t be persisted
       - bundle: Bundle containing your model.
     */
    public init(name: String, inMemory: Bool, bundle: Bundle) {
        guard let mom = NSManagedObjectModel.mergedModel(from: [bundle]) else {
            preconditionFailure("Failed to create mom")
        }
        guard bundle.url(forResource: name, withExtension: "momd") != nil else {
            preconditionFailure("The bundle doesn’t contain a model \(name).momd")
        }
        self.modelName = name
        super.init(name: name, managedObjectModel: mom)
        persistentStoreDescriptions = [
            inMemory ? inMemoryStoreDescription : sqliteStoreDescription
        ]
    }

    private var context: NSManagedObjectContext {
        viewContext
    }

    /*
     Execute the given block in a do/catch and wrap any error as `PersistenceError.other(error)`.

     - Parameter block: Block to run.
     - Returns: the result of the block.
    */
    private func wrapError<T>(_ block: () throws -> T) throws -> T {
        do {
            return try block()
        } catch {
            throw PersistenceError.other(error as NSError)
        }
    }

    // MARK: -

    /**
     Query with a predicate.

     The queried entity is passed as a generic parameter.
     - Parameter predicate: The predicate for a fetch request.
     - Returns: Zero or more managed objects.
     */
    @MainActor
    public func read<T: NSManagedObject>(predicate: NSPredicate? = nil) throws -> [T] {
        try wrapError {
            let name = T.entityName()
            let fetchRequest = NSFetchRequest<T>(entityName: name)
            fetchRequest.predicate = predicate
            return try context.fetch(fetchRequest)
        }
    }

    /**
     Save the given array of `Persistable` instances.
     - Parameter model: objects to be mapped and saved as managed objects.
     */
    @MainActor
    public func save<T: Persistable>(model: [T]) async throws {
        try wrapError {
            let mo = model.map { $0.mapPersistable(context: context) }
            try context.save()
            log.debug("Saved \(mo.count) models.")
        }
    }

    /**
     Loads the persistent stores.

     See `PersistentContainer.loadPersistentStores()`.

     - Parameters
       - retry: true to attempt recovery by deleting the previous store.
       - completionHandler: Once the loading of the persistent stores has completed, this block
                            will be executed on the calling thread.
     */
    public func loadPersistentStores(retry: Bool = true, completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {

        loadPersistentStores { desc, error in

            self.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            self.viewContext.shouldDeleteInaccessibleFaults = true

            let error = error.flatMap { PersistenceError.storeFailedLoading($0 as NSError) }

            guard let error = error else {
                block(desc, nil) /* success */
                return
            }

            guard error.isMigrationError, !retry else {
                block(desc, error) /* error */
                return
            }

            self.log.error("Migration failed. Wiping out the database to attempt recovery.")
            self.wipeSQLDatabase()
            self.loadPersistentStores(retry: false, completionHandler: block)
        }
    }
}
