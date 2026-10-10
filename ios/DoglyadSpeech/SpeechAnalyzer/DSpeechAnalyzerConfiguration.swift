import Foundation
import Speech

@available(iOS 26.0, *)
enum DSpeechAnalyzerConfiguration {
    static func makeTranscriber(
        locale: Locale,
        isFarField: Bool,
        includeConfidence: Bool = false,
    ) -> DictationTranscriber {
        var contentHints: Set<DictationTranscriber.ContentHint> = []
        if isFarField {
            contentHints.insert(
                .farField,
            )
        }

        return DictationTranscriber(
            locale: locale,
            contentHints: contentHints,
            transcriptionOptions: [.punctuation],
            reportingOptions: [.volatileResults],
            attributeOptions: includeConfidence ? [.transcriptionConfidence] : [],
        )
    }

    static func setContext(
        on analyzer: SpeechAnalyzer,
        contextualStrings: [String],
    ) async throws {
        guard !contextualStrings.isEmpty else { return }

        let context = AnalysisContext()
        context.contextualStrings[
            .general,
        ] = contextualStrings
        try await analyzer.setContext(
            context,
        )
    }

    static func installModelIfNeeded(
        transcriber: DictationTranscriber,
    ) async throws {
        let modules: [any SpeechModule] = [transcriber]
        switch await AssetInventory.status(
            forModules: modules,
        ) {
        case .installed:
            return
        case .supported, .downloading:
            guard let request = try await AssetInventory.assetInstallationRequest(
                supporting: modules,
            ) else {
                throw DSpeechError.unavailable
            }
            try await request.downloadAndInstall()
        case .unsupported:
            throw DSpeechError.unavailable
        }

        switch await AssetInventory.status(
            forModules: modules,
        ) {
        case .installed:
            return
        case .supported, .downloading, .unsupported:
            throw DSpeechError.unavailable
        }
    }
}
