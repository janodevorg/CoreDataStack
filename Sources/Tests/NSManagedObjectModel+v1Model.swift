import CoreData

extension NSManagedObjectModel {
    /// Creates a v1 model with basic Person entity
    static var v1Model: NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Create Person entity
        let personEntity = NSEntityDescription()
        personEntity.name = "Person"
        personEntity.managedObjectClassName = "PersonMO"

        // Add basic attributes
        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = false

        let ageAttr = NSAttributeDescription()
        ageAttr.name = "age"
        ageAttr.attributeType = .integer16AttributeType
        ageAttr.isOptional = false

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false

        personEntity.properties = [nameAttr, ageAttr, idAttr]
        model.entities = [personEntity]

        return model
    }
}
