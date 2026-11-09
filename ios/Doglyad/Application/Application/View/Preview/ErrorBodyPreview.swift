#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 ErrorBodyView ContentLoadFailed",
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
