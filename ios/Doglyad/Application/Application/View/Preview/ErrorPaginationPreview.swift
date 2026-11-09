#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 ErrorPaginationView NextPageLoadFailed",
    ) {
        ErrorPaginationView(
            description: L10NPreviewFactory.make().text(
                .errorUnknownDescription,
            ),
            onRetry: {},
        )
        .padding(
            16,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }
#endif
