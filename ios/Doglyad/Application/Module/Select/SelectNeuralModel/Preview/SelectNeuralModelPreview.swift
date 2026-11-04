#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "SelectNeuralModelContentState",
    ) {
        SelectNeuralModelPreviewView(
            state: SelectNeuralModelContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SelectNeuralModelSelectingState",
    ) {
        SelectNeuralModelPreviewView(
            state: SelectNeuralModelSelectingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
