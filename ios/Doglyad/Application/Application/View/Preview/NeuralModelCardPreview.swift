#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 NeuralModelCardView RequestsAvailable",
        traits: .sizeThatFitsLayout,
    ) {
        NeuralModelCardView(
            modelTitle: ModulePreviewFactory.neuralModel.title,
            availableRequestCount: 30,
            onTap: {},
        )
        .padding(
            16,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "02 NeuralModelCardView DailyLimitReached",
        traits: .sizeThatFitsLayout,
    ) {
        NeuralModelCardView(
            modelTitle: ModulePreviewFactory.neuralModel.title,
            availableRequestCount: 0,
            onTap: {},
        )
        .padding(
            16,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }
#endif
