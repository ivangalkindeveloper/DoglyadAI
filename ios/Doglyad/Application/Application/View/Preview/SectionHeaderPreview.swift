#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 Локализованный заголовок",
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
        "02 Заголовок из конфигурации",
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
