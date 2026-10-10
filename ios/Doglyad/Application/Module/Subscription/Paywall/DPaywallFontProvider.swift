import DoglyadUI
import RevenueCatUI
import SwiftUI

struct DPaywallFontProvider: PaywallFontProvider {
    private let typography: DTypography

    init(
        typography: DTypography = .shared,
    ) {
        self.typography = typography
    }

    func font(
        for textStyle: Font.TextStyle,
    ) -> Font {
        switch textStyle {
        case .largeTitle:
            return typography.displayHugeBold
        case .title:
            return typography.displayLargeBold
        case .title2:
            return typography.displayMediumBold
        case .title3:
            return typography.displaySmallBold
        case .headline:
            return typography.linkMedium
        case .body, .callout:
            return typography.textMedium
        case .subheadline:
            return typography.textSmall
        case .footnote, .caption, .caption2:
            return typography.textXSmall
        @unknown default:
            return typography.textMedium
        }
    }
}
