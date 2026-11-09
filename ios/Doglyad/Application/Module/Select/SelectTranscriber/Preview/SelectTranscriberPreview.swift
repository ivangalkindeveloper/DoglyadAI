#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectTranscriberInitialState AvailableTranscribers",
    ) {
        SelectTranscriberPreviewView(
            state: SelectTranscriberInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectTranscriberInitialState AvailableTranscribers ScrollEnd",
    ) {
        SelectTranscriberPreviewView(
            state: SelectTranscriberInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
