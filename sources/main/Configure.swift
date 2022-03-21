import Foundation

/**
 A protocol that combines creation and configuration in one block.

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
