import SwiftUI

public struct DTypography {
    public let displayHuge: Font
    public let displayLarge: Font
    public let displayMedium: Font
    public let displaySmall: Font

    public let displayHugeBold: Font
    public let displayLargeBold: Font
    public let displayMediumBold: Font
    public let displaySmallBold: Font

    public let textLarge: Font
    public let textMedium: Font
    public let textSmall: Font
    public let textXSmall: Font

    public let linkLarge: Font
    public let linkMedium: Font
    public let linkSmall: Font
    public let linkXSmall: Font
}

public extension DTypography {
    static let shared = DTypography(
        displayHuge: .custom(.MontserratRegular, 32),
        displayLarge: .custom(.MontserratRegular, 28),
        displayMedium: .custom(.MontserratRegular, 24),
        displaySmall: .custom(.MontserratRegular, 20),

        displayHugeBold: .custom(.MontserratBold, 32),
        displayLargeBold: .custom(.MontserratBold, 28),
        displayMediumBold: .custom(.MontserratBold, 24),
        displaySmallBold: .custom(.MontserratBold, 20),

        textLarge: .custom(.MontserratRegular, 20),
        textMedium: .custom(.MontserratRegular, 16),
        textSmall: .custom(.MontserratRegular, 14),
        textXSmall: .custom(.MontserratMedium, 12),

        linkLarge: .custom(.MontserratSemiBold, 20),
        linkMedium: .custom(.MontserratSemiBold, 16),
        linkSmall: .custom(.MontserratSemiBold, 14),
        linkXSmall: .custom(.MontserratSemiBold, 12)
    )
}
