#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 NeuralModelValueRowView ModelName",
        traits: .sizeThatFitsLayout,
    ) {
        NeuralModelValueRowView(
            title: L10NPreviewFactory.make()[
                .settingsAICardModelLabel,
            ],
            value: ModulePreviewFactory.neuralModel.title,
        )
        .padding(
            16,
        )
        .dThemeWrapper()
    }

    #Preview(
        "02 NeuralModelValueRowView NumericValue",
        traits: .sizeThatFitsLayout,
    ) {
        NeuralModelValueRowView(
            title: L10NPreviewFactory.make()[
                .neuralModelCardAvailableRequestsLabel,
            ],
            value: "30",
        )
        .padding(
            16,
        )
        .dThemeWrapper()
    }
#endif
