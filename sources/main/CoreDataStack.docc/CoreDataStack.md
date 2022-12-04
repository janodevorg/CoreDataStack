# ``CoreDataStack``

A minimal stack for Core Data.

## Overview

This package has these classes:

![Core Data stack](CoreDataStack)

They exist to simplify writing a CRUD with Core Data.

## Usage

### Writing a managed model

Let’s say your API produces a Codable model that you want to persist. Start by writing an equivalent managed object model.

Given a Codable model:

![Person@2x.png](Person)

Write equivalent objects as NSManagedObject subclasses:

![PersonMO@2x.png](PersonMO)

Then create a `Model.xcdatamodeld` file using Xcode Core Data editor.

### Initializing the container

Use the `Model.xcdatamodeld` you created before to initialize the PersistentContainer:

```swift
let container = PersistentContainer(name: "Model", inMemory: true, bundle: Bundle.module)
container.loadPersistentStores { desc, error in
    // error handling
}
```
Sidenote: if your model is in a target and you expect to test it from a test target, you’ll have to expose the `Bundle.module` of the target. This is unrelated to Core Data or this library. The test targets have their own bundle and can’t access the bundles of other targets. Adding a class like this inside the target should be enough:
```swift
public enum BundleReference {
    public static let bundle = Bundle.module
}
```

### Mapping models and managed objects

Add a convenience constructor to build the managed object with a model. This little saving will become a lot once you write many objects.
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

From here, mapping a model to a managed object is trivial:
```swift
extension Person: Persistable {
    public func mapPersistable(context: NSManagedObjectContext) -> PersonMO {
        PersonMO(model: self, context: context)
    }
}
```

### Writing models to Core Data

At this point we can persist objects like this:
```swift
let person = try createPersonFromJSON()
let personMO = person.mapPersistable(context: context)
try container.newBackgroundContext().save()
```

Or, given that our model implements Persistable, let the container do the mapping for you:
```swift
let person = try createPersonFromJSON()
try await container.save([person])
```

### Reading models from Core Data

To read the entities call `read()`. The type will be inferred.

```swift
let persons: [PersonMO] = try await container.read()
```

## Topics

### Group

- ``CoreDataStack/CoreDataTransformers``
- ``CoreDataStack/Persistable``
- ``CoreDataStack/PersistenceError``
- ``CoreDataStack/PersistentContainer``
