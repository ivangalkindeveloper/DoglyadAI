#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectNeuralModelContentState",
    ) {
        SelectNeuralModelPreviewView(
            state: SelectNeuralModelContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectNeuralModelSelectingState",
    ) {
        SelectNeuralModelPreviewView(
            state: SelectNeuralModelSelectingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
