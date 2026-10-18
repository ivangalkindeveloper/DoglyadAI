@testable import DoglyadSpeech
import Foundation
import Testing
import WhisperKit

struct DSpeechClinicalCorrectionTests {
    private let corrector = DSpeechLexiconCorrector(
        terms: ["мочевого пузыря", "анэхогенное содержимое", "гиперэхогенной взвеси", "эхопризнаки взвеси"],
        localization: VoiceLocalizationTestSupport.speech(
            locale: Locale(
                identifier: "ru",
            ),
        ),
    )

    @Test
    func medicalCorrectionsPreserveMeasurementsAndNegations() {
        let raw = "Стенка 2,7 мм. Содержимое анофагенное с гиперэфагенной взвесью. Эфопризнаки взвеси. Объём мучего пузыря 180 мл. Камней нет."
        let corrected = corrector.correct(
            raw,
        )
        #expect(
            corrected == "Стенка 2,7 мм. Содержимое анэхогенное с гиперэхогенной взвесью. Эхопризнаки взвеси. Объём мочевого пузыря 180 мл. Камней нет.",
        )
        #expect(
            corrector.correct(
                corrected,
            ) == corrected,
        )
    }

    @Test
    func oppositeTermsAndUnrelatedComplaintsRemainUntouched() {
        let text = "Гипоэхогенное образование слева. Гиперэхогенное образование справа. Боли при ночи спорта."
        #expect(
            corrector.correct(
                text,
            ) == text,
        )
        let unrelated = DSpeechLexiconCorrector(
            terms: ["митральный клапан"],
            localization: VoiceLocalizationTestSupport.speech(
                locale: Locale(
                    identifier: "ru",
                ),
            ),
        )
        #expect(
            unrelated.correct(
                "Содержимое анофагенное",
            ) == "Содержимое анофагенное",
        )
    }

    @Test(
        arguments: [false, true],
    )
    func suffixRemovalRequiresAudioEvidence(
        _ isSpeechDetected: Bool,
    ) {
        let raw = "Камней нет. Продолжение следует..."
        let range = (raw as NSString).range(
            of: "Продолжение следует...",
        )
        let span = DSpeechDecodingSpan(
            utf16Start: range.location,
            utf16Length: range.length,
            averageLogProbability: -0.1,
            temperature: 0,
            compressionRatio: 1,
            recheckedText: "Продолжение следует",
            isSpeechDetected: isSpeechDetected,
        )
        #expect(
            corrector.correct(
                raw,
                decodingSpans: [span],
            ) == (isSpeechDetected ? raw : "Камней нет."),
        )
        #expect(
            corrector.correct(
                raw,
            ) == raw,
        )
    }

    @Test
    func absentAudioDoesNotDeleteAClinicalFinding() {
        let raw = "Камней нет."
        let span = DSpeechDecodingSpan(
            utf16Start: 0,
            utf16Length: (raw as NSString).length,
            averageLogProbability: -0.1,
            temperature: 0,
            compressionRatio: 1,
            recheckedText: nil,
            isSpeechDetected: false,
        )
        #expect(
            corrector.correct(
                raw,
                decodingSpans: [span],
            ) == raw,
        )
    }

    @Test
    func segmentActivityIsMeasuredForShortRecordingsAndMappedToEvidence() throws {
        #expect(
            !DSpeechWhisperKitTranscription.hasAudioActivity(
                [Float](
                    repeating: 0,
                    count: 16000,
                ),
            ),
        )
        #expect(
            DSpeechWhisperKitTranscription.hasAudioActivity(
                [Float](
                    repeating: 0.05,
                    count: 16000,
                ),
            ),
        )
        let transcription = DSpeechWhisperKitTranscription(
            results: [TranscriptionResult(
                text: "Volume 180 ml.",
                segments: [TranscriptionSegment(
                    text: "Volume 180 ml.",
                )],
                language: "en",
                timings: TranscriptionTimings(),
            )],
            repeatedTexts: ["Volume 180 ml."],
            speechActivity: [false],
        )
        #expect(
            try #require(
                transcription.decodingSpans.first,
            ).isSpeechDetected == false,
        )
    }
}
