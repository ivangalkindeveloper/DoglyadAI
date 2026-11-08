#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 Одна строка — лимит 3",
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
        "02 Три строки — лимит 3",
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
        "03 Четыре строки — лимит 3",
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
        "04 Длинный текст — ширина 360",
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
        "05 Длинный текст — ширина 260",
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
        "06 Длинный текст — лимит 1",
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
        "07 Markdown — лимит 3",
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
