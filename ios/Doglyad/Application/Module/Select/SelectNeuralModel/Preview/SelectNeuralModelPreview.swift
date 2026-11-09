#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectNeuralModelInitialState AvailableModels",
    ) {
        SelectNeuralModelPreviewView(
            state: SelectNeuralModelInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectNeuralModelInitialState AvailableModels ScrollEnd",
    ) {
        SelectNeuralModelPreviewView(
            state: SelectNeuralModelInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

#endif
