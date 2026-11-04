#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "AboutState",
    ) {
        AboutPreviewView(
            state: AboutState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
