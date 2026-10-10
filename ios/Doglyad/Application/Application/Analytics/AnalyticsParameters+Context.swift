import DoglyadNeuralModel
import DoglyadSpeech
import Foundation

extension AnalyticsParameters {
    static func speechToggle(
        status: DSpeechRecordingStatus,
    ) -> Self {
        let source = switch status {
        case .preparing: "preparing"
        case .recording: "recording"
        case .transcribing: "transcribing"
        case .stopped: "stopped"
        }
        return Self(
            [.source: .string(
                source,
            )],
        )
    }

    static func dictationReviewed(
        completion: DSpeechCompletion,
    ) -> Self {
        Self(
            [.result: .string(
                completion.rawValue,
            )],
        )
    }

    static func voiceProposalApplied(
        proposals: [DNeuralUltrasoundVoiceFieldProposal],
        source: AnalyticsVoiceProposalSource,
    ) -> Self {
        Self(
            [
                .source: .string(
                    source.rawValue,
                ),
                .itemCount: .int(
                    proposals.count,
                ),
                .warningCount: .int(
                    proposals.reduce(
                        0,
                    ) { $0 + $1.warnings.count },
                ),
            ],
        )
    }

    static func voiceProposalsGenerated(
        proposal: DNeuralUltrasoundDictationProposal,
        startedAt: Date,
        completedAt: Date = .now,
    ) -> Self {
        Self(
            [
                .itemCount: .int(
                    proposal.proposals.count,
                ),
                .warningCount: .int(
                    proposal.proposals.reduce(
                        0,
                    ) { $0 + $1.warnings.count },
                ),
                .rejectedCount: .int(
                    proposal.rejectedFieldIds.count,
                ),
                .durationMs: .int(
                    Int(
                        completedAt.timeIntervalSince(
                            startedAt,
                        ) * 1000,
                    ),
                ),
            ],
        )
    }

    static func initializationError(
        _ error: any Error,
    ) -> Self {
        let name = switch error as? InitializationError {
        case .noInternetConnection: "no_internet_connection"
        case .serviceUnavailable: "service_unavailable"
        case .newVersion: "new_version"
        case .usExaminationTypesEmpty: "examination_types_empty"
        case .usExaminationNeuralModelsEmpty: "neural_models_empty"
        case .common: "common"
        case .none: "unknown"
        }
        return Self(
            [.error: .string(
                name,
            )],
        )
    }

    static func neuralModelSelection(
        currentModelId: String?,
    ) -> Self {
        var values: [AnalyticsParameter: AnalyticsValue] = [
            .hasCurrentValue: .bool(
                currentModelId != nil,
            ),
        ]
        if let currentModelId {
            values[
                .modelId,
            ] = .string(
                currentModelId,
            )
        }
        return Self(
            values,
        )
    }

    static func subscription(
        type: SubscriptionType?,
    ) -> Self {
        Self(
            [.subscriptionType: .string(
                type?.rawValue ?? "none",
            )],
        )
    }

    static func onboardingPage(
        index: Int,
    ) -> Self {
        Self(
            [.source: .string(
                String(
                    index + 1,
                ),
            )],
        )
    }

    static func document(
        url: URL,
    ) -> Self {
        Self(
            [.document: .string(
                AnalyticsDocument(
                    url: url,
                ).rawValue,
            )],
        )
    }
}
