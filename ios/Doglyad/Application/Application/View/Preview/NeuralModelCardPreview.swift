#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 Доступны запросы",
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
        "02 Лимит запросов исчерпан",
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
