import AVFoundation
import Foundation
import Speech

/// Replays a WAV through the iOS 26 dictation engine with the same recognition
/// settings and lexicon correction as the microphone controller.
@available(iOS 26.0, *)
public final class DSpeechFileTranscriber {
    public init() {}

    public func transcribe(
        fileURL: URL,
        locale: Locale,
        contextualStrings: [String],
        useHints: Bool = true,
        useCorrection: Bool = true
    ) async throws -> DSpeechFileTranscription {
        guard let resolvedLocale = await DictationTranscriber.supportedLocale(equivalentTo: locale) else {
            throw DSpeechFileTranscriberError.unsupportedLocale
        }

        let transcriber = DSpeechAnalyzerConfiguration.makeTranscriber(
            locale: resolvedLocale,
            isFarField: true,
            includeConfidence: true
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await DSpeechAnalyzerConfiguration.setContext(
            on: analyzer,
            contextualStrings: useHints ? contextualStrings : []
        )
        try await DSpeechAnalyzerConfiguration.installModelIfNeeded(
            transcriber: transcriber
        )

        let audioFile = try AVAudioFile(forReading: fileURL)
        let availableFormats = await transcriber.availableCompatibleAudioFormats
        guard !availableFormats.isEmpty else {
            let status = await AssetInventory.status(forModules: [transcriber])
            throw DSpeechFileTranscriberError.noCompatibleAudioFormat(
                assetStatus: String(describing: status),
                availableFormats: availableFormats.count
            )
        }
        let resultTask = Task { () throws -> (String, [DSpeechConfidenceSpan]) in
            var finalizedText = AttributedString()
            for try await result in transcriber.results {
                if result.isFinal {
                    finalizedText += result.text
                }
            }
            return (String(finalizedText.characters), DSpeechConfidenceSpan.from(finalizedText))
        }

        do {
            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
            let (rawText, confidenceSpans) = try await resultTask.value
            let correctedText = useCorrection
                ? DSpeechLexiconCorrector(terms: contextualStrings).correct(rawText)
                : rawText
            return DSpeechFileTranscription(
                rawText: rawText,
                correctedText: correctedText,
                confidenceSpans: confidenceSpans
            )
        } catch {
            resultTask.cancel()
            await analyzer.cancelAndFinishNow()
            let assetStatus = await AssetInventory.status(forModules: [transcriber])
            throw DSpeechFileTranscriberError.recognitionFailed(
                "\(error); asset status: \(assetStatus); compatible formats: \(availableFormats.count)"
            )
        }
    }
}
