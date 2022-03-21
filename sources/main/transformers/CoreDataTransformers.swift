import Foundation

/// Contains a reversible transformer between NSNumber and NSString.
public enum CoreDataTransformers
{
    /// Reversible transformer for NSString -> NSNumber?.
    static let stringToNumber = "StringToNumber"

    // NSString -> NSNumber?
    private static func stringToNumber(value: NSString) -> NSNumber? {
        value.integerValue as NSNumber
    }

    // NSNumber -> NSString?
    private static func numberToString(value: NSNumber) -> NSString? {
        NSString(utf8String: value.description)
    }

    /// Register the transformers in this file.
    public static func register() {
        NSSecureUnarchiveFromDataTransformer.setValueTransformer(
            transform: stringToNumber,
            reverseTransform: numberToString,
            forName: stringToNumber
        )
    }
}
