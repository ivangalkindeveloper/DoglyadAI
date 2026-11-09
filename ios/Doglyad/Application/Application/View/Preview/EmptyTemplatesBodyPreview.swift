#if DEBUG
    import SwiftUI

    #Preview(
        "01 EmptyTemplatesBodyView EmptyCatalog",
    ) {
        EmptyTemplatesBodyView(
            description: L10NPreviewFactory.make()[
                .templateListEmptyDescription,
            ],
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
