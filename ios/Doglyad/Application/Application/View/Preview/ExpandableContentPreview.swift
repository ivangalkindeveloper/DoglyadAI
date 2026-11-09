#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 ExpandableContentView OneLine",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .short,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "02 ExpandableContentView ThreeLines",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .threeLines,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "03 ExpandableContentView FourLines",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .fourLines,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "04 ExpandableContentView LongTextWide",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .long,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "05 ExpandableContentView LongTextNarrow",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .narrow,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "06 ExpandableContentView OneLineLimit",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .singleLineLimit,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "07 ExpandableContentView Markdown",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .markdown,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }
#endif
