import AVFoundation
import CryptoKit
@testable import Doglyad
import DoglyadDatabase
import DoglyadNetwork
@testable import DoglyadNeuralModel
@testable import DoglyadSpeech
import FirebaseCore
import Foundation
import FoundationModels
import WhisperKit
import XCTest

final class VoiceEndToEndTests: XCTestCase {
    @MainActor
    func testReadyAudioThroughProductionPipeline() async throws {
        guard ProcessInfo.processInfo.environment[
            "VOICE_END_TO_END_RUN",
        ] == "1" else {
            throw XCTSkip(
                "Requires a physical iPhone, App Attest and prepared end-to-end audio",
            )
        }
        #if DEBUG || targetEnvironment(
            simulator,
        )
        XCTFail(
            "Use Release-Development on a physical iPhone to exercise App Attest",
        )
        return
        #else
        try await runPipeline()
        #endif
    }

    @MainActor
    private func runPipeline() async throws {
        for _ in 0 ..< 100 where FirebaseApp.app() == nil {
            try await Task.sleep(
                for: .milliseconds(
                    100,
                ),
            )
        }
        XCTAssertNotNil(
            FirebaseApp.app(),
            "The application must configure its real Firebase provider",
        )
        let bundle = Bundle(
            for: Self.self,
        )
        let fixtureName = ProcessInfo.processInfo.environment[
            "VOICE_FIXTURE_NAME",
        ] ?? "end-to-end"
        let fixtureURL = try XCTUnwrap(
            bundle.url(
                forResource: fixtureName,
                withExtension: "json",
                subdirectory: "VoiceFixtures",
            )
                ?? bundle.url(
                    forResource: fixtureName,
                    withExtension: "json",
                ),
        )
        let fixtureData = try Data(
            contentsOf: fixtureURL,
        )
        let fixtureHash = SHA256.hash(
            data: fixtureData,
        ).map { String(
            format: "%02x",
            $0,
        ) }.joined()
        let fixture = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: fixtureData,
            ) as? [String: Any],
        )
        var cases = try XCTUnwrap(
            fixture[
                "cases",
            ] as? [[String: Any]],
        )
        let localeFilter = ProcessInfo.processInfo.environment[
            "VOICE_END_TO_END_LOCALE",
        ]
        let foundationOnly = ProcessInfo.processInfo.environment[
            "VOICE_END_TO_END_REQUIRE_FOUNDATION_MODELS",
        ] == "1"
        if let localeFilter {
            cases = cases.filter { $0[
                "locale",
            ] as? String == localeFilter }
        }
        XCTAssertFalse(
            cases.isEmpty,
            "The selected locale must contain fixture cases",
        )
        if let limit = ProcessInfo.processInfo.environment[
            "VOICE_END_TO_END_LIMIT",
        ].flatMap(
            Int.init,
        ) {
            cases = Array(
                cases.prefix(
                    limit,
                ),
            )
        }
        // Replay only measured ASR, never old extraction or form results. A
        // changed parser/gate must process every case again under one version.
        var cachedASR: [String: [String: Any]] = [:]
        var checkpointHash: String?
        if let name = ProcessInfo.processInfo.environment[
            "VOICE_ASR_CHECKPOINT",
        ] {
            let url = try XCTUnwrap(
                bundle.url(
                    forResource: name,
                    withExtension: "json",
                    subdirectory: "VoiceFixtures",
                )
                    ?? bundle.url(
                        forResource: name,
                        withExtension: "json",
                    ),
            )
            let data = try Data(
                contentsOf: url,
            )
            let checkpoint = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: data,
                ) as? [String: Any],
            )
            guard checkpoint[
                "inputMode",
            ] as? String == "audio",
                checkpoint[
                    "fixtureSha256",
                ] as? String == fixtureHash else { throw CheckpointError.mismatchedInput }
            let rows = try XCTUnwrap(
                checkpoint[
                    "results",
                ] as? [[String: Any]],
            )
            for row in rows where row[
                "rawText",
            ] is String && row[
                "asrSegments",
            ] is [[String: Any]] {
                let id = try XCTUnwrap(
                    row[
                        "id",
                    ] as? String,
                )
                guard let item = cases.first(
                    where: { $0[
                        "id",
                    ] as? String == id },
                ) else { continue }
                for key in ["audioSha256", "inputText", "expectedFields"] {
                    XCTAssertEqual(
                        item[
                            key,
                        ] as? NSObject,
                        row[
                            key,
                        ] as? NSObject,
                        "Checkpoint mismatch: \(id) / \(key)",
                    )
                    guard item[
                        key,
                    ] as? NSObject == row[
                        key,
                    ] as? NSObject else { throw CheckpointError.mismatchedInput }
                }
                guard cachedASR.updateValue(
                    row,
                    forKey: id,
                ) == nil else { throw CheckpointError.duplicateCase }
            }
            checkpointHash = SHA256.hash(
                data: data,
            ).map { String(
                format: "%02x",
                $0,
            ) }.joined()
        }
        let client = DHttpClient(
            baseUrl: Bundle.dictionaryString(
                .BASE_URL,
            ),
            baseVersionPrefix: "/v1",
            interceptor: AppCheckHttpInterceptor(),
        )
        let repository = try UltrasoundReportRepository(
            database: DDatabase(),
            httpClient: client,
        )
        var configurations: [String: ApplicationConfig] = [:]
        var types: [String: [String: USExaminationType]] = [:]
        let localeCodes = Set(
            cases.compactMap { $0[
                "locale",
            ] as? String },
        ).sorted()
        for code in localeCodes {
            let headers = [DHttpHeader.acceptLanguage: code]
            let config: ApplicationConfig = try await client.get(
                endPoint: "/application_config",
                headers: headers,
            )
            configurations[
                code,
            ] = config
            let groups: [USExaminationTypeGroup] = try await client.get(
                endPoint: "/ultrasound/examination_types",
                headers: headers,
            )
            types[
                code,
            ] = Dictionary(
                uniqueKeysWithValues: groups.flatMap(
                    \.examinationTypes,
                ).map { ($0.id, $0) },
            )
            client.updateConfiguration(
                timeoutIntervalForRequest: config.network.timeoutIntervalForRequest,
                timeoutIntervalForResource: config.network.timeoutIntervalForResource,
            )
        }
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask,
        )[
            0,
        ]
        // Reuse the Turbo model already downloaded for the ASR comparison on this phone.
        let cached = documents.appendingPathComponent(
            "VoiceWhisperKitModel",
        )
        if FileManager.default.fileExists(
            atPath: cached.appendingPathComponent(
                "AudioEncoder.mlmodelc",
            ).path,
        ) {
            UserDefaults.standard.set(
                cached.path,
                forKey: "DoglyadSpeech.whisperTurboModelFolder",
            )
        }
        let textOnly = ProcessInfo.processInfo.environment[
            "VOICE_END_TO_END_TEXT_ONLY",
        ] == "1"
        let loadStarted = Date()
        let model: WhisperKit? = if textOnly || cases.allSatisfy(
            { cachedASR[
                $0[
                    "id",
                ] as? String ?? "",
            ] != nil },
        ) {
            nil
        } else {
            try await DSpeechWhisperKitModel.shared.load()
        }
        let loadSeconds = Date().timeIntervalSince(
            loadStarted,
        )
        let runID = ProcessInfo.processInfo.environment[
            "VOICE_REPORT_ID",
        ] ?? "manual"
        let destination = documents.appendingPathComponent(
            "voice-end-to-end-\(runID).json",
        )
        var results: [[String: Any]] = []
        for item in cases {
            var row = item
            let started = Date()
            var serverCalls = 0
            var foundationCalls = 0
            do {
                let code = try XCTUnwrap(
                    item[
                        "locale",
                    ] as? String,
                )
                let locale = Locale(
                    identifier: code,
                )
                let typeID = try XCTUnwrap(
                    item[
                        "examinationTypeId",
                    ] as? String,
                )
                let type = try XCTUnwrap(
                    types[
                        code,
                    ]?[
                        typeID,
                    ],
                )
                let filename = try XCTUnwrap(
                    item[
                        "audioFile",
                    ] as? String,
                )
                let audioURL = try XCTUnwrap(
                    bundle.url(
                        forResource: (filename as NSString).deletingPathExtension,
                        withExtension: "wav",
                        subdirectory: "VoiceFixtures",
                    )
                        ?? bundle.url(
                            forResource: (filename as NSString).deletingPathExtension,
                            withExtension: "wav",
                        ),
                )
                XCTAssertEqual(
                    try SHA256.hash(
                        data: Data(
                            contentsOf: audioURL,
                        ),
                    ).map { String(
                        format: "%02x",
                        $0,
                    ) }.joined(),
                    item[
                        "audioSha256",
                    ] as? String,
                )
                let audio = try AVAudioFile(
                    forReading: audioURL,
                )
                let duration = Double(
                    audio.length,
                ) / audio.processingFormat.sampleRate
                let asrStarted = Date()
                let raw: String
                var decodingSpans: [DSpeechDecodingSpan] = []
                if textOnly {
                    raw = try XCTUnwrap(
                        item[
                            "inputText",
                        ] as? String,
                    )
                } else if let cached = try cachedASR[
                    XCTUnwrap(
                        item[
                            "id",
                        ] as? String,
                    ),
                ] {
                    let transcription = try replayASR(
                        cached,
                        language: code,
                    )
                    raw = transcription.rawText
                    decodingSpans = transcription.decodingSpans
                    for key in ["asrSegments", "asrRechecks", "asrRecheckSeconds", "asrSeconds"] {
                        row[
                            key,
                        ] = cached[
                            key,
                        ]
                    }
                    row[
                        "asrDecodingSeconds",
                    ] = transcription.decodingSeconds
                    row[
                        "asrReusedFromSha256",
                    ] = checkpointHash
                } else {
                    let transcription = try await DSpeechWhisperKitTranscription.transcribe(
                        model: XCTUnwrap(
                            model,
                        ),
                        audioPath: audioURL.path,
                        language: code,
                        duration: duration,
                    )
                    raw = transcription.rawText
                    decodingSpans = transcription.decodingSpans
                    row[
                        "asrSegments",
                    ] = transcription.segments.map { segment in
                        [
                            "text": segment.text,
                            "start": segment.start,
                            "end": segment.end,
                            "avgLogprob": segment.avgLogprob,
                            "compressionRatio": segment.compressionRatio,
                            "temperature": segment.temperature,
                        ] as [String: Any]
                    }
                    row[
                        "asrRechecks",
                    ] = zip(
                        transcription.segments,
                        transcription.repeatedTexts,
                    ).map { segment, repeated in
                        [
                            "originalText": segment.text,
                            "repeatedText": repeated,
                            "start": segment.start,
                            "end": segment.end,
                        ] as [String: Any]
                    }
                    row[
                        "asrRecheckSeconds",
                    ] = transcription.recheckSeconds
                    row[
                        "asrDecodingSeconds",
                    ] = transcription.decodingSeconds
                }
                let text = textOnly ? raw : DSpeechLexiconCorrector(
                    terms: type.contextualStrings,
                    localization: VoiceLocalizationTestSupport.speech(
                        locale: locale,
                    ),
                ).correct(
                    raw,
                )
                row[
                    "rawText",
                ] = raw
                row[
                    "correctedText",
                ] = text
                if row[
                    "asrReusedFromSha256",
                ] == nil { row[
                    "asrSeconds",
                ] = Date().timeIntervalSince(
                    asrStarted,
                ) }
                let transcript = DSpeechTranscript(
                    rawText: raw,
                    correctedText: text,
                    locale: locale,
                    engine: .whisperKit,
                    completion: .finished,
                    decodingSpans: decodingSpans,
                )
                XCTAssertTrue(
                    transcript.isReadyForParsing,
                )
                let config = try XCTUnwrap(
                    configurations[
                        code,
                    ],
                ).ultrasound.examinationNeuralModel
                let parameters = DNeuralGenerationParameters(
                    temperature: config.temperature,
                    maxTokens: config.maxTokens,
                    maxContextTokens: config.maxContextTokens,
                )
                let foundationProvider = DNeuralUltrasoundRecordingFoundationProvider(
                    base: DNeuralUltrasoundFoundationModelProvider(
                        locale: locale,
                        proposalPrompt: config.proposalPrompt,
                        parameters: parameters,
                    ),
                )
                let transport = DNeuralUltrasoundRetryingTestTransport(
                    base: repository,
                    foundationOnly: foundationOnly,
                )
                let factory = DNeuralUltrasoundModelFactory(
                    foundationProvider: foundationProvider,
                    serverModel: DNeuralUltrasoundModelServer(
                        transport: transport,
                    ),
                )
                defer {
                    foundationCalls = foundationProvider.recorder?.calls ?? 0
                    serverCalls = transport.calls
                }
                let request = DNeuralUltrasoundDictationParseRequest(
                    text: text,
                    examinationTypeId: typeID,
                    examinationTypeTitle: type.title,
                    locale: locale,
                    allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
                    localization: VoiceLocalizationTestSupport.dictation(
                        locale: locale,
                    ),
                )
                let available = foundationProvider.isAvailable
                row[
                    "labeledProposals",
                ] = DNeuralUltrasoundDictationLabeledFormParser.parse(
                    request: request,
                )?.proposals.map(
                    proposalJSON,
                ) ?? []
                row[
                    "explicitProposals",
                ] = DNeuralUltrasoundDictationExplicitFactsExtractor.extract(
                    request: request,
                ).map(
                    proposalJSON,
                )
                row[
                    "foundationAvailable",
                ] = available
                if #available(iOS 26.0, *) {
                    row[
                        "foundationSystemAvailability",
                    ] = String(
                        describing: SystemLanguageModel.default.availability,
                    )
                    row[
                        "foundationSupportsLocale",
                    ] = SystemLanguageModel.default.supportsLocale(
                        locale,
                    )
                }
                if foundationOnly, !available { throw DNeuralModelError.unavailable }
                let parseStarted = Date()
                defer {
                    if let error = foundationProvider.recorder?.error {
                        row[
                            "foundationGenerationError",
                        ] = String(
                            describing: error,
                        )
                    }
                    if let generated = foundationProvider.recorder?.generated {
                        row[
                            "rawFoundationResponse",
                        ] = ["proposals": generated.proposals.map { item in
                            ["field_id": item.fieldId.wireValue, "value": item.value, "evidence": item.sourceQuote, "accuracy": item.accuracy.rawValue]
                        }, "unmappedFindings": generated.unmappedFindings] as [String: Any]
                        if let checked = try? DNeuralUltrasoundProposalProcessor.validate(
                            generated: generated,
                            request: request,
                        ) {
                            row[
                                "validatedFoundationProposals",
                            ] = checked.proposals.map(
                                self.proposalJSON,
                            )
                            row[
                                "foundationRejectedFieldIds",
                            ] = checked.rejectedFieldIds.map(
                                \.wireValue,
                            )
                        }
                    }
                }
                let model = try factory.model()
                let proposal = try await model.parseProposals(
                    request: request,
                )
                foundationCalls = foundationProvider.recorder?.calls ?? 0
                serverCalls = transport.calls
                row[
                    "parseSeconds",
                ] = Date().timeIntervalSince(
                    parseStarted,
                )
                row[
                    "proposalSource",
                ] = String(
                    describing: proposal.source,
                )
                XCTAssertEqual(
                    foundationCalls,
                    available ? 1 : 0,
                )
                XCTAssertEqual(
                    serverCalls > 0,
                    !available,
                )
                let plan = ScanSpeechConfidencePolicy.plan(
                    proposal: proposal,
                    transcript: transcript,
                    parsedText: text,
                    noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                        locale: transcript.locale,
                    ).pattern(
                        .noComplaintsValue,
                    ),
                )
                let baseline = baselineForm()
                let automatic = try XCTUnwrap(
                    ScanFormPatch.apply(
                        plan.automatic,
                        to: baseline,
                    ),
                )
                let confirmed = try XCTUnwrap(
                    ScanFormPatch.apply(
                        plan.uncertain,
                        to: automatic,
                    ),
                )
                let before = formValues(
                    baseline,
                )
                let afterAutomatic = formValues(
                    automatic,
                )
                let afterConfirmed = formValues(
                    confirmed,
                )
                let automaticIDs = Set(
                    plan.automatic.map(
                        \.id,
                    ),
                )
                let proposedIDs = Set(
                    proposal.proposals.map(
                        \.id,
                    ),
                )
                XCTAssertTrue(
                    automaticIDs.isDisjoint(
                        with: Set(
                            plan.uncertain.map(
                                \.id,
                            ),
                        ),
                    ),
                )
                XCTAssertEqual(
                    proposedIDs,
                    automaticIDs.union(
                        plan.uncertain.map(
                            \.id,
                        ),
                    ),
                )
                for field in DNeuralUltrasoundVoiceFieldId.allCases {
                    if !automaticIDs.contains(
                        field,
                    ) { XCTAssertEqual(
                        before[
                            field.rawValue,
                        ] as? AnyHashable,
                        afterAutomatic[
                            field.rawValue,
                        ] as? AnyHashable,
                    ) }
                    if !proposedIDs.contains(
                        field,
                    ) { XCTAssertEqual(
                        before[
                            field.rawValue,
                        ] as? AnyHashable,
                        afterConfirmed[
                            field.rawValue,
                        ] as? AnyHashable,
                    ) }
                }
                row[
                    "response",
                ] = ["proposals": proposal.proposals.map(
                    proposalJSON,
                ), "rejectedFieldIds": proposal.rejectedFieldIds.map(
                    \.wireValue,
                ), "unmappedFindings": proposal.unmappedFindings]
                row[
                    "automaticFieldIds",
                ] = plan.automatic.map(
                    \.id.rawValue,
                )
                row[
                    "reviewFieldIds",
                ] = plan.uncertain.map(
                    \.id.rawValue,
                )
                row[
                    "formBefore",
                ] = before
                row[
                    "formAfterAutomatic",
                ] = afterAutomatic
                row[
                    "formAfterConfirmation",
                ] = afterConfirmed
                row[
                    "status",
                ] = "ok"
                factory.unload()
            } catch {
                row[
                    "status",
                ] = "failed"
                row[
                    "error",
                ] = String(
                    describing: error,
                )
            }
            row[
                "serverAttempts",
            ] = serverCalls
            row[
                "foundationCalls",
            ] = foundationCalls
            row[
                "elapsedSeconds",
            ] = Date().timeIntervalSince(
                started,
            )
            results.append(
                row,
            )
            let report: [String: Any] = ["runId": runID, "fixtureSha256": fixtureHash, "sourceSha256": ProcessInfo.processInfo.environment[
                "VOICE_SOURCE_SHA256",
            ] ?? "unrecorded", "inputMode": textOnly ? "ideal-text" : "audio", "modelLabel": "large-v3-v20240930_626MB", "modelLoadSeconds": loadSeconds, "baseURL": client.baseUrl, "appCheckProvider": "AppAttest", "localeFilter": localeFilter ?? "all", "requireFoundationModels": foundationOnly, "results": results]
            try JSONSerialization.data(
                withJSONObject: report,
                options: [.prettyPrinted, .sortedKeys],
            ).write(
                to: destination,
                options: .atomic,
            )
            print(
                "VOICE_END_TO_END_PROGRESS=\(results.count)/\(cases.count)",
            )
        }
        XCTAssertEqual(
            results.count,
            cases.count,
        )
        XCTAssertTrue(
            results.allSatisfy { ($0[
                "status",
            ] as? String) == "ok" },
            "Inspect the report for failed pipeline requests",
        )
        print(
            "VOICE_END_TO_END_REPORT=\(destination.path)",
        )
    }

    private enum CheckpointError: Error {
        case mismatchedInput, duplicateCase
    }

    private func replayASR(
        _ row: [String: Any],
        language: String,
    ) throws -> DSpeechWhisperKitTranscription {
        let raw = try XCTUnwrap(
            row[
                "rawText",
            ] as? String,
        )
        let stored = try XCTUnwrap(
            row[
                "asrSegments",
            ] as? [[String: Any]],
        )
        let repeats = try XCTUnwrap(
            row[
                "asrRechecks",
            ] as? [[String: Any]],
        )
        guard stored.count == repeats.count else { throw CheckpointError.mismatchedInput }
        var segments: [TranscriptionSegment] = []
        var repeatedTexts: [String] = []
        for (segment, repeated) in zip(
            stored,
            repeats,
        ) {
            let text = try XCTUnwrap(
                segment[
                    "text",
                ] as? String,
            )
            guard repeated[
                "originalText",
            ] as? String == text else { throw CheckpointError.mismatchedInput }
            try segments.append(
                TranscriptionSegment(
                    start: XCTUnwrap(
                        segment[
                            "start",
                        ] as? NSNumber,
                    ).floatValue,
                    end: XCTUnwrap(
                        segment[
                            "end",
                        ] as? NSNumber,
                    ).floatValue,
                    text: text,
                    temperature: XCTUnwrap(
                        segment[
                            "temperature",
                        ] as? NSNumber,
                    ).floatValue,
                    avgLogprob: XCTUnwrap(
                        segment[
                            "avgLogprob",
                        ] as? NSNumber,
                    ).floatValue,
                    compressionRatio: XCTUnwrap(
                        segment[
                            "compressionRatio",
                        ] as? NSNumber,
                    ).floatValue,
                ),
            )
            try repeatedTexts.append(
                XCTUnwrap(
                    repeated[
                        "repeatedText",
                    ] as? String,
                ),
            )
        }
        let recheck = try XCTUnwrap(
            row[
                "asrRecheckSeconds",
            ] as? Double,
        )
        let decoding = try (row[
            "asrDecodingSeconds",
        ] as? Double) ?? (XCTUnwrap(
            row[
                "asrSeconds",
            ] as? Double,
        ) - recheck)
        return DSpeechWhisperKitTranscription(
            results: [TranscriptionResult(
                text: raw,
                segments: segments,
                language: language,
                timings: TranscriptionTimings(),
            )],
            repeatedTexts: repeatedTexts,
            decodingSeconds: decoding,
            recheckSeconds: recheck,
        )
    }

    private func proposalJSON(
        _ proposal: DNeuralUltrasoundVoiceFieldProposal,
    ) -> [String: Any] {
        ["field_id": proposal.id.wireValue, "value": valueJSON(
            proposal.value,
        ), "evidence": proposal.sourceQuote, "accuracy": proposal.accuracy.rawValue, "warnings": proposal.warnings.map { String(
            describing: $0,
        ) }]
    }

    private func valueJSON(
        _ value: DNeuralVoiceFieldValue,
    ) -> Any {
        switch value {
        case let .text(
            value,
        ): value
        case let .number(
            value,
        ): value
        case let .gender(
            value,
        ):
            switch value { case .male: "male"
            case .female: "female" }
        case let .date(
            value,
        ): dateString(
                value,
            )
        }
    }

    private func dateString(
        _ date: Date,
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(
            identifier: .gregorian,
        )
        formatter.locale = Locale(
            identifier: "en_US_POSIX",
        )
        formatter.timeZone = TimeZone(
            secondsFromGMT: 0,
        )
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(
            from: date,
        )
    }

    private func baselineForm() -> USExaminationDraftForm {
        USExaminationDraftForm(
            examinationNumber: "KEEP-ID",
            patientName: "KEEP-NAME",
            patientGender: .male,
            patientDateOfBirth: Date(
                timeIntervalSince1970: 0,
            ),
            patientHeightCM: "199",
            patientWeightKG: "99",
            patientComplaints: "KEEP-COMPLAINTS",
            examinationDescription: "KEEP-DESCRIPTION",
        )
    }

    private func formValues(
        _ form: USExaminationDraftForm,
    ) -> [String: Any] {
        ["examinationNumber": form.examinationNumber, "patientName": form.patientName, "patientGender": form.patientGender.rawValue, "patientDateOfBirth": dateString(
            form.patientDateOfBirth,
        ), "patientHeightCM": form.patientHeightCM, "patientWeightKG": form.patientWeightKG, "patientComplaints": form.patientComplaints, "examinationDescription": form.examinationDescription]
    }
}
