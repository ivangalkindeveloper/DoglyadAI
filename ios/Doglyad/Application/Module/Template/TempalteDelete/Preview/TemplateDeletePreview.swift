#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateDeleteState",
    ) {
        TemplateDeletePreviewView(
            state: TemplateDeleteState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
