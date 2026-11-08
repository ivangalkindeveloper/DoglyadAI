#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectNeuralModelInitialState",
    ) {
        SelectNeuralModelPreviewView(
            state: SelectNeuralModelInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectNeuralModelSelectionLoadingState",
    ) {
        SelectNeuralModelPreviewView(
            state: SelectNeuralModelSelectionLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
