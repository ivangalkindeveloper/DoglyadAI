#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 SettingsAICardView DefaultPreferences",
        traits: .sizeThatFitsLayout,
    ) {
        SettingsAICardView(
            settings: ModulePreviewFactory.makeContainer().initialSettingsAI,
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
        "02 SettingsAICardView MarkdownEnabled",
        traits: .sizeThatFitsLayout,
    ) {
        let settings = ModulePreviewFactory.makeContainer().initialSettingsAI

        SettingsAICardView(
            settings: SettingsAI(
                transcriberType: settings.transcriberType,
                transcriptParserType: settings.transcriptParserType,
                selectedNeuralModelId: settings.selectedNeuralModelId,
                isMarkdown: true,
                temperature: settings.temperature,
                maxTokens: settings.maxTokens,
            ),
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
