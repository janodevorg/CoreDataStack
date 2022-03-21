# ``CoreDataStack``

A minimal stack for Core Data.

## Overview

![Core Data stack](CoreDataStack)

### Writing a managed model

Given a codable model

![Person@2x.png](Person)

Write a matching managed object model.

![PersonMO@2x.png](PersonMO)

### Initializing the container

Given a `Model.xcdatamodeld`

```swift
let container = PersistentContainer(name: "Model", inMemory: true, bundle: Bundle.module)
container.loadPersistentStores { desc, error in
    // error handling
}
```
Note that if your model is in a target and you expect to test it from a test target, you’ll have to expose the `Bundle.module` of the target writing a class like this inside the target:
```swift
public enum BundleReference {
    public static let bundle = Bundle.module
}
```
This is unrelated to Core Data or this library. The test targets have their own bundle and can’t access the bundles of other targets.

### Mapping

Add a convenience constructor to build the managed object with a model. This is simplified a little
with a NSManagedObject extension. This little saving will become a lot once you write many objects.
```swift
import Foundation
import CoreData

extension PersonMO
{
    convenience init(model: Person, context: NSManagedObjectContext) {
        self.init(using: context)
        id = model.id
        name = model.name

        // dog relation
        if let modelDogs: [Dog] = model.dogs {
            let dogs: [DogMO] = modelDogs.map { DogMO(model: $0, context: context) }
            dogs.forEach { $0.owner = self }
            self.dogs = NSSet(array: dogs)
        }
    }
}
```

Mapping a model to a managed object is trivial:
```swift
extension Person: Persistable {
    public func mapPersistable(context: NSManagedObjectContext) -> PersonMO {
        PersonMO(model: self, context: context)
    }
}
```

### Writing

Now we can create objects using code like this:
```swift
let person = try createPersonFromJSON()
let personMO = person.mapPersistable(context: context)
try container.newBackgroundContext().save()
```

Or, given that our model implements Persistable:
```swift
let person = try createPersonFromJSON()
try await container.save([person])
```

### Reading

To read the entities just call `read()`. The type will be inferred.

```swift
let persons: [PersonMO] = try await container.read()
```

## Topics

### Group

- ``CoreDataStack/CoreDataTransformers``
- ``CoreDataStack/Persistable``
- ``CoreDataStack/PersistenceError``
- ``CoreDataStack/PersistentContainer``
