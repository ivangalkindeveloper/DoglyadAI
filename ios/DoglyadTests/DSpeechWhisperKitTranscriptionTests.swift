@testable import DoglyadSpeech
import Foundation
import Testing
import WhisperKit

struct DSpeechWhisperKitTranscriptionTests {
    @Test(
        "Decoder special tokens never change UTF-16 source offsets",
    )
    func mapsLiteralSegments() throws {
        let result = TranscriptionResult(
            text: "😀 No fever. Weight 82 kg.",
            segments: [
                TranscriptionSegment(
                    text: "<|0.00|> No fever.<|1.50|>",
                    temperature: 0,
                    avgLogprob: -0.2,
                ),
                TranscriptionSegment(
                    text: "<|1.50|> Weight 82 kg.<|3.50|>",
                    temperature: 0,
                    avgLogprob: -0.1,
                ),
            ],
            language: "en",
            timings: TranscriptionTimings(),
        )
        let transcription = DSpeechWhisperKitTranscription(
            results: [result],
            repeatedTexts: ["No fever.", "Weight 182 kg."],
        )
        #expect(
            transcription.decodingSpans.count == 2,
        )
        let first = try #require(
            transcription.decodingSpans.first,
        )
        #expect(
            first.utf16Start == ("😀 " as NSString).length,
        )
        #expect(
            first.isStable(
                quote: "No fever.",
            ),
        )
        #expect(
            !transcription.decodingSpans[
                1,
            ].isStable(
                quote: "82",
            ),
        )
    }
}
