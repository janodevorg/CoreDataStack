import Foundation

// Forward only transformer.
private class ForwardValueTransformer: NSSecureUnarchiveFromDataTransformer
{
    private let transform: (Any?) -> (Any?)

    init(transform: @escaping (Any?) -> (Any?)) {
        self.transform = transform
    }

    // MARK: - NSValueTransformer

    override class func allowsReverseTransformation() -> Bool {
        false
    }

    override class func transformedValueClass() -> AnyClass {
        NSObject.self
    }

    func transformedValue(value: Any?) -> Any? {
        transform(value)
    }
}

// Forward/backward transformer.
private final class ReversibleValueTransformer: ForwardValueTransformer
{
    private let reverseTransform: (Any?) -> (Any?)

    init(transform: @escaping (Any?) -> (Any?), reverseTransform: @escaping (Any?) -> (Any?)) {
        self.reverseTransform = reverseTransform
        super.init(transform: transform)
    }

    // MARK: - NSValueTransformer

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    func reverseTransformedValue(value: Any?) -> Any? {
        reverseTransform(value)
    }
}

public extension NSSecureUnarchiveFromDataTransformer {

    /// Creates a forward transformation based on a generic function.
    static func setValueTransformer<T, U>(
        transform: @escaping (T) -> (U?),
        forName name: String
    ) {
        let transformer = ForwardValueTransformer { value in
            (value as? T).flatMap {
                transform($0)
            }
        }
        setValueTransformer(transformer, forName: NSValueTransformerName(name))
    }

    /// Creates a reversible transformation based on a generic function.
    static func setValueTransformer<T, U>(
        transform: @escaping (T) -> (U?),
        reverseTransform: @escaping (U) -> (T?),
        forName name: String
    ) {
        let transformer = ReversibleValueTransformer(transform: { value in
            (value as? T).flatMap {
                transform($0)
            }
        }, reverseTransform: { value in
            (value as? U).flatMap {
                reverseTransform($0)
            }
        })
        setValueTransformer(transformer, forName: NSValueTransformerName(name))
    }
}
