#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 Ошибка загрузки",
    ) {
        ErrorBodyView(
            description: L10NPreviewFactory.make().text(
                .errorUnknownDescription,
            ),
        )
        .padding(
            16,
        )
        .dThemeWrapper()
    }
#endif
