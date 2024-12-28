import Foundation

/**
 A protocol that enables creation and configuration of objects in a single expression.

 Usage:
 ```
    var label = UILabel().configure {
        $0.backgroundColor = .blue
        $0.text = "blah"
    }
 ```
 */
protocol Configure {}

extension Configure where Self: Any {

    @discardableResult
    func configure(_ block: (inout Self) -> Void) -> Self {

        var copy = self
        block(&copy)
        return copy
    }
}

extension NSObject: Configure {}
