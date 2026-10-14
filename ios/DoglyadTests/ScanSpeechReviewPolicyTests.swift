@testable import Doglyad
import DoglyadSpeech
import Foundation
import Testing

struct ScanSpeechReviewPolicyTests {
    @Test(
        "A completed dictation sends the exact visible text to the parser",
    )
    func finishedUsesVisibleText() {
        let edited = "  Правая почка 12 мм.  "
        let result = ScanSpeechReviewPolicy.textForParsing(
            transcript: transcript(
                completion: .finished,
            ),
            visibleText: edited,
        )
        #expect(
            result == edited,
        )
    }

    @Test(
        "An incomplete dictation can use its unchanged transcript",
    )
    func incompletePreservesUsableText() {
        let partial = transcript(
            completion: .timedOut,
        )
        let unchanged = ScanSpeechReviewPolicy.textForParsing(
            transcript: partial,
            visibleText: "Правая почка 12 мм",
        )
        let whitespaceOnly = ScanSpeechReviewPolicy.textForParsing(
            transcript: partial,
            visibleText: "  Правая почка 12 мм  ",
        )
        let corrected = ScanSpeechReviewPolicy.textForParsing(
            transcript: partial,
            visibleText: "Правая почка 12 мм, конкрементов нет",
        )
        #expect(
            unchanged == "Правая почка 12 мм",
        )
        #expect(
            whitespaceOnly == "  Правая почка 12 мм  ",
        )
        #expect(
            corrected == "Правая почка 12 мм, конкрементов нет",
        )
    }

    @Test(
        "Empty text and cancelled recordings cannot continue",
    )
    func refusesEmptyAndCancelled() {
        let emptyResult = ScanSpeechReviewPolicy.textForParsing(
            transcript: transcript(
                completion: .finished,
            ),
            visibleText: " \n ",
        )
        let cancelled = ScanSpeechReviewPolicy.textForParsing(
            transcript: transcript(
                completion: .cancelled,
            ),
            visibleText: "Правая почка 12 мм",
        )
        #expect(
            emptyResult == nil,
        )
        #expect(
            cancelled == nil,
        )
    }

    private func transcript(
        completion: DSpeechCompletion,
    ) -> DSpeechTranscript {
        DSpeechTranscript(
            rawText: "Правая почка 12 мм",
            correctedText: "Правая почка 12 мм",
            locale: Locale(
                identifier: "ru_RU",
            ),
            engine: .speechAnalyzer,
            completion: completion,
        )
    }
}
