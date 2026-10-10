import Foundation
import WhisperKit

struct DSpeechWhisperKitTranscription: Sendable {
    let rawText: String
    let decodingSpans: [DSpeechDecodingSpan]
    let segments: [TranscriptionSegment]
    let repeatedTexts: [String]
    let decodingSeconds: TimeInterval
    let recheckSeconds: TimeInterval

    init(
        results: [TranscriptionResult],
        repeatedTexts: [String] = [],
        decodingSeconds: TimeInterval = 0,
        recheckSeconds: TimeInterval = 0,
    ) {
        segments = results.flatMap(
            \.segments,
        )
        self.repeatedTexts = repeatedTexts
        self.decodingSeconds = decodingSeconds
        self.recheckSeconds = recheckSeconds
        rawText = results.map(
            \.text,
        ).joined(
            separator: " ",
        ).trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        var cursor = rawText.startIndex
        var spans: [DSpeechDecodingSpan] = []
        for (index, segment) in results.flatMap(
            \.segments,
        ).enumerated() {
            let text = segment.text.replacingOccurrences(
                of: #"<\|[^|]*\|>"#,
                with: "",
                options: .regularExpression,
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines,
            )
            guard !text.isEmpty, let range = rawText.range(
                of: text,
                range: cursor ..< rawText.endIndex,
            ) else {
                // Mapping failure leaves this portion uncovered: it cannot
                // establish eligibility for automatic filling.
                continue
            }
            cursor = range.upperBound
            let position = NSRange(
                range,
                in: rawText,
            )
            spans.append(
                DSpeechDecodingSpan(
                    utf16Start: position.location,
                    utf16Length: position.length,
                    averageLogProbability: Double(
                        segment.avgLogprob,
                    ),
                    temperature: Double(
                        segment.temperature,
                    ),
                    compressionRatio: Double(
                        segment.compressionRatio,
                    ),
                    recheckedText: index < repeatedTexts.count ? repeatedTexts[
                        index,
                    ] : nil,
                ),
            )
        }
        decodingSpans = spans
    }

    static func transcribe(
        model: WhisperKit,
        audioPath: String,
        language: String,
        duration: Double,
    ) async throws -> Self {
        let started = Date()
        let results = try await model.transcribe(
            audioPath: audioPath,
            decodeOptions: DecodingOptions(
                language: language,
                chunkingStrategy: duration > 30 ? .vad : nil,
            ),
        )
        let decodingSeconds = Date().timeIntervalSince(
            started,
        )
        let checkStarted = Date()
        var repeatedTexts: [String] = []
        for segment in results.flatMap(
            \.segments,
        ) {
            try Task.checkCancellation()
            guard segment.end > segment.start else { repeatedTexts.append(
                "",
            )
            continue
            }
            do {
                let samples = try AudioProcessor.loadAudioAsFloatArray(
                    fromPath: audioPath,
                    startTime: max(
                        0,
                        Double(
                            segment.start,
                        ) - 0.35,
                    ),
                    endTime: min(
                        duration,
                        Double(
                            segment.end,
                        ) + 0.35,
                    ),
                )
                let repeated = try await model.transcribe(
                    audioArray: samples,
                    decodeOptions: DecodingOptions(
                        language: language,
                    ),
                )
                repeatedTexts.append(
                    repeated.map(
                        \.text,
                    ).joined(
                        separator: " ",
                    ),
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Failure to verify a fragment must not discard the recording.
                // Its missing evidence sends affected fields to confirmation.
                repeatedTexts.append(
                    "",
                )
            }
        }
        return Self(
            results: results,
            repeatedTexts: repeatedTexts,
            decodingSeconds: decodingSeconds,
            recheckSeconds: Date().timeIntervalSince(
                checkStarted,
            ),
        )
    }
}
