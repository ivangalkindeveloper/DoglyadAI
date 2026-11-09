#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 SectionHeaderView LocalizedTitle",
        traits: .sizeThatFitsLayout,
    ) {
        SectionHeaderView(
            title: L10NPreviewFactory.make()[
                .historyTitle,
            ],
        )
        .padding(
            16,
        )
        .dThemeWrapper()
    }

    #Preview(
        "02 SectionHeaderView ConfigurationTitle",
        traits: .sizeThatFitsLayout,
    ) {
        SectionHeaderView(
            title: ModulePreviewFactory.examinationType.title,
        )
        .padding(
            16,
        )
        .dThemeWrapper()
    }
#endif
