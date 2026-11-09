#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 AboutDefaultState ApplicationInformation",
    ) {
        AboutPreviewView(
            state: AboutDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
