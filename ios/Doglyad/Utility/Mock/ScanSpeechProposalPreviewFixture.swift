#if DEBUG
    import DoglyadNeuralModel
    import DoglyadUI
    import Foundation

    @MainActor
    struct ScanSpeechProposalPreviewFixture {
        enum Scenario: Hashable {
            case patientName
            case measurement
            case clinicalText
            case multipleFields
            case partialResult
            case empty
        }

        let state: ScanSpeechReviewProposalState
        let automaticFieldIds: Set<DNeuralUltrasoundVoiceFieldId>

        init(
            scenario: Scenario,
            isSelected: Bool = false,
        ) {
            let patientName = DNeuralUltrasoundVoiceFieldProposal(
                id: .patientName,
                value: .text(
                    "Иванов Иван Иванович",
                ),
                sourceQuote: "Пациент Иванов Иван Иванович.",
                accuracy: .questionable,
            )
            let measurement = DNeuralUltrasoundVoiceFieldProposal(
                id: .patientHeightCM,
                value: .number(
                    175,
                ),
                sourceQuote: "Рост метр семьдесят пять, то есть сто семьдесят пять сантиметров.",
                warnings: [.numberMismatch, .unitMismatch],
            )
            let clinicalText = DNeuralUltrasoundVoiceFieldProposal(
                id: .examinationDescription,
                value: .text(
                    "Правая почка обычных размеров, контуры ровные, чёткие. В нижней чашечке определяется гиперэхогенное включение до 4 мм с акустической тенью. Чашечно-лоханочная система не расширена.",
                ),
                sourceQuote: "Левая почка обычных размеров, контуры ровные, чёткие. Конкрементов и расширения чашечно-лоханочной системы нет. Правую почку пока не оценивали.",
                warnings: [.sideMismatch, .negationMismatch, .textChanged],
            )
            let reviewProposals: [DNeuralUltrasoundVoiceFieldProposal] = switch scenario {
            case .patientName: [patientName]
            case .measurement: [measurement]
            case .clinicalText: [clinicalText]
            case .multipleFields: [patientName, measurement, clinicalText]
            case .partialResult: [measurement]
            case .empty: []
            }
            let automaticProposals: [DNeuralUltrasoundVoiceFieldProposal] = switch scenario {
            case .multipleFields, .partialResult:
                [
                    DNeuralUltrasoundVoiceFieldProposal(
                        id: .examinationNumber,
                        value: .text(
                            "00123",
                        ),
                        sourceQuote: "Номер исследования ноль ноль сто двадцать три.",
                    ),
                    DNeuralUltrasoundVoiceFieldProposal(
                        id: .patientGender,
                        value: .gender(
                            .male,
                        ),
                        sourceQuote: "Пол мужской.",
                    ),
                ]
            case .patientName, .measurement, .clinicalText, .empty: []
            }
            let selectedFieldIds: Set<DNeuralUltrasoundVoiceFieldId> = switch scenario {
            case .multipleFields: [.patientName]
            case .patientName, .measurement, .clinicalText, .partialResult, .empty: []
            }

            automaticFieldIds = Set(
                automaticProposals.map(
                    \.id,
                ),
            )
            state = ScanSpeechReviewProposalState(
                proposal: DNeuralUltrasoundDictationProposal(
                    source: .serverModel,
                    proposals: automaticProposals + reviewProposals,
                ),
                reviewProposals: reviewProposals,
                selectedFieldIds: isSelected ? Set(
                    reviewProposals.map(
                        \.id,
                    ),
                ) : selectedFieldIds,
            )
        }

        func makeViewModel(
            container: DependencyContainer,
            messager: DMessager,
            router: DRouter,
        ) -> ScanSpeechViewModel {
            let model = ScanSpeechPreviewFactory.makeViewModel(
                container: container,
                messager: messager,
                router: router,
            )
            model.automaticFieldIds = automaticFieldIds
            model.emit(
                state,
                animation: nil,
            )
            return model
        }
    }
#endif
