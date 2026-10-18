@testable import DoglyadSpeech
import Foundation
import Testing
import WhisperKit

struct DSpeechWhisperKitTranscriptionTests {
    @Test
    func previewJoinsConfirmedAndDraftSegmentsWithoutDecoderTokens() {
        let text = DSpeechWhisperKitTranscription.previewText(
            unconfirmedSegments: [
                TranscriptionSegment(
                    text: "<|startoftranscript|> Вес 70 кг. ",
                ),
                TranscriptionSegment(
                    text: "<|1.20|> Рост 175 см.<|endoftext|>",
                ),
            ],
        )
        #expect(
            text == "Вес 70 кг. Рост 175 см.",
        )
        #expect(
            DSpeechWhisperKitTranscription.previewText(
                unconfirmedSegments: [TranscriptionSegment(
                    text: "<|endoftext|>  ",
                )],
            ) == nil,
        )
    }

    @Test
    func promotingDraftSegmentsDoesNotRepeatTheirText() {
        let first = TranscriptionSegment(
            start: 0,
            end: 1,
            text: "Weight 70 kg.",
        )
        let second = TranscriptionSegment(
            start: 1,
            end: 2,
            text: "Height 175 cm.",
        )
        let text = DSpeechWhisperKitTranscription.previewText(
            confirmedSegments: [first],
            unconfirmedSegments: [first, second],
        )
        #expect(
            text == "Weight 70 kg. Height 175 cm.",
        )
    }

    @Test
    func recheckSamplesIncludeContextAndStayInsideTheRecording() {
        let audio = (0 ..< WhisperKit.sampleRate).map { Float(
            $0,
        ) }
        let samples = DSpeechWhisperKitTranscription.samples(
            for: TranscriptionSegment(
                start: 0.1,
                end: 0.2,
                text: "Weight",
            ),
            in: audio,
        )
        #expect(
            samples.first == 0,
        )
        #expect(
            samples.last == 8799,
        )
        #expect(
            samples.count == 8800,
        )
        #expect(
            DSpeechWhisperKitTranscription.samples(
                for: TranscriptionSegment(
                    start: 0.8,
                    end: 1.2,
                    text: "Weight",
                ),
                in: audio,
            ).last == Float(
                WhisperKit.sampleRate - 1,
            ),
        )
    }

    @Test(
        arguments: [
            (Float.nan, Float(
                1,
            )),
            (Float(
                0,
            ), Float.infinity),
            (Float(
                2,
            ), Float(
                1,
            )),
            (Float(
                1,
            ), Float(
                1,
            )),
            (Float(
                10,
            ), Float(
                11,
            )),
        ],
    )
    func invalidOrOutOfBoundsSegmentsDoNotProduceRecheckEvidence(
        start: Float,
        end: Float,
    ) {
        let samples = DSpeechWhisperKitTranscription.samples(
            for: TranscriptionSegment(
                start: start,
                end: end,
                text: "Weight",
            ),
            in: [Float](
                repeating: 0,
                count: WhisperKit.sampleRate,
            ),
        )
        #expect(
            samples.isEmpty,
        )
    }

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
