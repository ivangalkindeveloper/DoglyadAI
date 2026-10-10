import SwiftUI

public extension Font {
    static func custom(
        _ family: DFontFamily,
        _ size: CGFloat,
    ) -> Font {
        Font.custom(
            family.rawValue,
            fixedSize: size,
        )
    }
}
