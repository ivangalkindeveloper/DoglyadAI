import UIKit

public extension UIScreen {
    var cornerRadius: CGFloat {
        value(
            forKey: "_displayCornerRadius",
        ) as? CGFloat ?? 16.0
    }
}
