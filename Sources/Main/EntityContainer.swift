import CoreData
import Foundation
import os

public protocol FileOperations {
    func fileExists(atPath path: String) -> Bool
    func removeItem(at url: URL) throws
    func copyItem(at srcURL: URL, to dstURL: URL) throws
}

extension FileManager: FileOperations {}

/**
A persistent container that provides a convenient way to set up Core Data storage.

Features:
- Support for both in-memory and SQLite storage
- Automatic migration handling
- Debug logging
- Database backup functionality
*/
open class EntityContainer: NSPersistentContainer, @unchecked Sendable {
    public typealias ManagedObject = NSManagedObject
    private let log = LoggerFactory.coredata.logger()

    /// When true, a fetch that takes more than 2 seconds will generate a warning. Default is false.
    public var isSlowQueryWarningEnabled = false

    // Name of the .xcdatamodeld directory, minus the extension.
    private let modelName: String

    // Persistence store description in memory.
    private lazy var inMemoryStore = NSPersistentStoreDescription().configure {
        $0.shouldAddStoreAsynchronously = false
        $0.type = NSInMemoryStoreType
        $0.url = URL(fileURLWithPath: "/dev/null")
    }

    // Persistence store description in SQLite.
    private lazy var sqliteStore = NSPersistentStoreDescription().configure {
        $0.shouldAddStoreAsynchronously = false
        $0.type = NSSQLiteStoreType
        $0.url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("\(modelName).sqlite")
    }

    public var context: NSManagedObjectContext {
        viewContext
    }

    internal var backupDirectory: URL = {
        let url = BackupDirectory.applicationSupport.url.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    internal var currentDate: () -> Date = { Date() }
    internal var fileOperations: FileOperations = FileManager.default

    /// - name: Name of the .xcdatamodeld directory containg your model, without the `.xcdatamodeld` extension.
    public init(name: String, model: NSManagedObjectModel, isInMemoryStore: Bool) {
        self.modelName = name
        super.init(name: name, managedObjectModel: model)
        persistentStoreDescriptions = [isInMemoryStore ? inMemoryStore : sqliteStore]
        log.debug("Initialized EntityContainer with custom model.")
    }

    /// - name: Name of the .xcdatamodeld directory containg your model, without the `.xcdatamodeld` extension.
    /// - bundle: Bundle containing your compiled model
    public convenience init(name: String, isInMemoryStore: Bool, bundle: Bundle) {
        guard let mom = NSManagedObjectModel.mergedModel(from: [bundle]) else {
            preconditionFailure("Failed to create merged model from bundle")
        }
        self.init(name: name, model: mom, isInMemoryStore: isInMemoryStore)
    }

    // MARK: - Backup

    /// Remove the existing database with backup functionality
    @discardableResult
    public func wipeSQLDatabase(backupFirst: Bool = true) throws -> URL? {
        log.info("Removing existing database.")
        let dbURL = backupDirectory.appendingPathComponent("\(modelName).sqlite")

        var backupURL: URL? = nil
        if backupFirst {
            backupURL = try backup(sourceURL: dbURL)
        }

        try fileOperations.removeItem(at: dbURL)
        return backupURL
    }

    // Modified backup function that returns the backup URL
    private func backup(sourceURL: URL) throws -> URL {
        let backupURL = sourceURL.appendingPathExtension("backup-\(dateTag())")

        if fileOperations.fileExists(atPath: backupURL.path) {
            try fileOperations.removeItem(at: backupURL)
        }

        log.info("Backing up at \(backupURL.absoluteString)")
        try fileOperations.copyItem(at: sourceURL, to: backupURL)
        return backupURL
    }

    // Returns the current date with format `yyyy-MM-dd'T'HHmmss`.
    private func dateTag() -> String {
        DateFormatter()
            .configure {
                $0.dateFormat = "yyyy-MM-dd'T'HHmmss"
                $0.timeZone = TimeZone(secondsFromGMT: 0)
                $0.locale = Locale(identifier: "en_US_POSIX")
            }
            .string(from: currentDate())
    }

    /*
     Execute the given block in a do/catch and wrap any error as `EntityContainerError.other(error)`.

     - Parameter tag: Message that will prefix the error when logged.
     - Parameter block: Block to run.
     - Returns: the result of the block.
     */
    private func wrapError<T>(tag: String, _ block: () throws -> T) throws(EntityContainerError) -> T {
        do {
            return try block()
        } catch {
            log.error("\(tag): \(error.localizedDescription)")
            throw EntityContainerError.other(error as NSError)
        }
    }

    override public func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        loadPersistentStores(retry: true, completionHandler: block)
    }

    /**
     Loads the persistent stores.

     See `PersistentContainer.loadPersistentStores()`.

     - Parameters
     - retry: true to attempt recovery by deleting the previous store.
     - completionHandler: Once the loading of the persistent stores has completed, this block
     will be executed on the calling thread.
     */
    public func loadPersistentStores(
        retry: Bool,
        completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void
    ) {
        super.loadPersistentStores { desc, error in
            self.context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            self.context.shouldDeleteInaccessibleFaults = true

            let error = error.flatMap { EntityContainerError.storeFailedLoading($0 as NSError) }

            guard let error = error else {
                block(desc, nil) /* success */
                return
            }

            guard error.isMigrationError, !retry else {
                self.log.error("Migration error. Not retrying.")
                block(desc, error) /* error */
                return
            }

            self.log.error("Migration failed. Wiping out the database to attempt recovery.")
            do {
                try self.wipeSQLDatabase()
                self.loadPersistentStores(retry: false, completionHandler: block)
            } catch {
                self.log.error("\(error)")
            }
        }
    }
}

extension EntityContainer {
    /// Return entities matching a given query.
    /// - Parameter slowThreshold: Limit in seconds before logging a warning.
    ///   Default is 2. Requires `isSlowQueryWarningEnabled = true`.
    public func fetch<T: ManagedObject>(_ query: EntityQuery<T> = .all, slowThreshold: TimeInterval = 2.0) throws -> [T] {
        if !isSlowQueryWarningEnabled {
            return try context.fetch(query.fetchRequest)
        }

        let startTime = DispatchTime.now()
        let results = try context.fetch(query.fetchRequest)
        let endTime = DispatchTime.now()
        let timeElapsed = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        if timeElapsed > slowThreshold {
            log.warning("""
                Slow fetch operation detected (\(String(format: "%.2f", timeElapsed))s):
                - Entity: \(String(describing: T.self))
                - Predicate: \(String(describing: query))
                - Results: \(results.count)
                """)
        }
        return results
    }

    /// Fetch all domain objects.
    public func fetch<T: ManagedObject & DomainConvertible>(_ query: EntityQuery<T>) throws -> [T.DomainModel] {
        let objects: [T] = try fetch(query)
        return try objects.map { try $0.toDomain() }
    }

    /// Fetches a single entity from the database.
    public func fetch<T: ManagedObject>(_ query: EntityQuery<T> = .all) throws -> T? {
        try fetch(query).first
    }

    /// Fetches a single entity from the database.
    /// Throws `EntityContainerError.fetchRequiredFailed` if not found.
    public func fetchRequired<T: ManagedObject>(_ query: EntityQuery<T>) throws -> T {
        guard let first = try fetch(query).first else {
            throw EntityContainerError.fetchRequiredFailed
        }
        return first
    }

    /// Fetches a single domain object from the database.
    /// Throws `EntityContainerError.fetchRequiredFailed` if not found.
    public func fetchRequired<T: ManagedObject & DomainConvertible>(_ query: EntityQuery<T>) throws -> T.DomainModel {
        guard let first = try fetch(query).first else {
            throw EntityContainerError.fetchRequiredFailed
        }
        return first
    }

    /// Save an array of domain objects.
    public func save<T: EntityConvertible>(models: [T]) async throws {
        try wrapError(tag: "Saving") {
            var objectsToSave: [NSManagedObject] = []

            for model in models {
                if let object = try model.toEntity(container: self) {
                    objectsToSave.append(object)
                }
            }

            if !objectsToSave.isEmpty {
                try context.save()
                log.debug("Saved \(objectsToSave.count) models.")
            }
        }
    }

    /// Returns the number of entities that match the given query, without fetching the actual objects.
    ///
    /// Note: the type parameter prevents T being inferred as NSManagedObject
    public func count<T: ManagedObject>(_ query: EntityQuery<T>, type: T.Type) throws -> Int {
       try context.count(for: query.fetchRequest)
    }

    /// Efficiently deletes dozens of objects or less.
    ///
    /// Note: the type parameter prevents T being inferred as NSManagedObject
    public func deleteAll<T: ManagedObject>(_ query: EntityQuery<T>, type: T.Type) throws {
        (try fetch(query) as [T])
            .forEach(context.delete)
    }

    /// Efficiently deletes hundreds of objects or more.
    /// - Note: batch delete is not supported with memory stores. Core Data will complain
    ///   with message *“Unknown command type <NSBatchDeleteRequest…”*.
    public func batchDeleteAll<T: ManagedObject>(_ query: EntityQuery<T>, type: T.Type) throws {
        try context.delete(matching: query.fetchRequest)
    }
}
