import CoreData
import CoreDataStack
import Foundation

struct Person: Codable {
    let id: Int64
    let name: String
    var dogs: [Dog]?
}

extension Person: Persistable {
    public func mapPersistable(context: NSManagedObjectContext) -> PersonMO {
        PersonMO(model: self, context: context)
    }
}
