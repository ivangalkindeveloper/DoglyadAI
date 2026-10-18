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
        let repeatedTexts = try await recheck(
            results: results,
            model: model,
            language: language,
        ) { segment in
            try AudioProcessor.loadAudioAsFloatArray(
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

    static func previewText(
        confirmedSegments: [TranscriptionSegment] = [],
        unconfirmedSegments: [TranscriptionSegment],
    ) -> String? {
        // SDK callbacks can promote confirmed segments before replacing the old
        // draft array. Audio timestamps prevent that transient overlap appearing twice.
        let drafts = unconfirmedSegments.filter { segment in
            guard let confirmedEnd = confirmedSegments.last?.end else { return true }
            return segment.end > confirmedEnd
        }
        let text = (confirmedSegments + drafts).map { segment in
            segment.text.replacingOccurrences(
                of: #"<\|[^|]*\|>"#,
                with: "",
                options: .regularExpression,
            ).trimmingCharacters(
                in: .whitespacesAndNewlines,
            )
        }.filter { !$0.isEmpty }.joined(
            separator: " ",
        )
        return text.isEmpty ? nil : text
    }

    static func transcribe(
        model: WhisperKit,
        audioArray: [Float],
        language: String,
    ) async throws -> Self {
        try Task.checkCancellation()
        let started = Date()
        let duration = Double(
            audioArray.count,
        ) / Double(
            WhisperKit.sampleRate,
        )
        let results = try await model.transcribe(
            audioArray: audioArray,
            decodeOptions: DecodingOptions(
                language: language,
                chunkingStrategy: duration > 30 ? .vad : nil,
            ),
        )
        let decodingSeconds = Date().timeIntervalSince(
            started,
        )
        let checkStarted = Date()
        let repeatedTexts = try await recheck(
            results: results,
            model: model,
            language: language,
        ) { segment in
            samples(
                for: segment,
                in: audioArray,
            )
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

    static func samples(
        for segment: TranscriptionSegment,
        in audioArray: [Float],
    ) -> [Float] {
        guard segment.start.isFinite, segment.end.isFinite, segment.end > segment.start else { return [] }
        let rate = Double(
            WhisperKit.sampleRate,
        )
        let duration = Double(
            audioArray.count,
        ) / rate
        let start = Int(
            min(
                duration,
                max(
                    0,
                    Double(
                        segment.start,
                    ) - 0.35,
                ),
            ) * rate,
        )
        let end = min(
            audioArray.count,
            Int(
                min(
                    duration,
                    max(
                        0,
                        Double(
                            segment.end,
                        ) + 0.35,
                    ),
                ) * rate,
            ),
        )
        guard end > start else { return [] }
        return Array(
            audioArray[
                start ..< end,
            ],
        )
    }

    private static func recheck(
        results: [TranscriptionResult],
        model: WhisperKit,
        language: String,
        samplesForSegment: (TranscriptionSegment) throws -> [Float],
    ) async throws -> [String] {
        var repeatedTexts: [String] = []
        for segment in results.flatMap(
            \.segments,
        ) {
            try Task.checkCancellation()
            guard segment.start.isFinite, segment.end.isFinite, segment.end > segment.start else {
                repeatedTexts.append(
                    "",
                )
                continue
            }
            do {
                let samples = try samplesForSegment(
                    segment,
                )
                guard !samples.isEmpty else {
                    repeatedTexts.append(
                        "",
                    )
                    continue
                }
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
                // Missing recheck evidence requires confirmation of the affected fields.
                repeatedTexts.append(
                    "",
                )
            }
        }
        return repeatedTexts
    }
}
