import DependencyInitializer
import Foundation

extension InitializationProcess {
    static let stepsTier5 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "Interrupted report generations",
                run: { @MainActor (process: InitializationProcess) async throws in
                    try await process.ultrasoundReportRepository!.interruptPendingGenerations()
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Recent examination types",
                run: { @MainActor (process: InitializationProcess) async throws in
                    let repository = process.ultrasoundReportRepository!
                    let recentIds = try await repository.getRecentExaminationTypeIds()
                    let availableIds = Set(
                        process.usExaminationTypesById!.keys,
                    )
                    try await repository.setRecentExaminationTypeIds(
                        USExaminationRecentTypes.available(
                            from: recentIds,
                            availableIds: availableIds,
                        ),
                    )
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Selected examination type",
                run: { @MainActor (process: InitializationProcess) async throws in
                    let repository = process.ultrasoundReportRepository!
                    let id = try await repository.getSelectedExaminationTypeId()
                    if let id, process.usExaminationTypesById![
                        id,
                    ] == nil {
                        try await repository.setSelectedExaminationTypeId(
                            id: process.usExaminationTypeDefault!.id,
                        )
                    }
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Stored AI settings",
                run: { @MainActor (process: InitializationProcess) async throws in
                    let settingsRepository = process.settingsAIRepository!
                    let storedSettings = try await settingsRepository.getSettings()
                    let selectedId = storedSettings?.selectedNeuralModelId
                    var resolvedModelId = selectedId
                    let selected = selectedId.flatMap {
                        process.usExaminationNeuralModelsById![
                            $0,
                        ]
                    }
                    let isSelectionAllowed: Bool
                    if let selected {
                        let isAvailable = switch selected.accessibility {
                        case .available: true
                        case .comingSoon, .unavailable: false
                        }
                        let isEntitled = switch selected.entitlement {
                        case .base: true
                        case .pro:
                            switch process.initialSubscriptionStatus?.type {
                            case .some(
                                .pro,
                            ): true
                            case .some(
                                .base,
                            ), .none: false
                            }
                        }
                        isSelectionAllowed = isAvailable && isEntitled
                    } else {
                        isSelectionAllowed = false
                    }
                    if !isSelectionAllowed {
                        let firstBaseModel = process.usExaminationNeuralModels!.first { model in
                            let isAvailable = switch model.accessibility {
                            case .available: true
                            case .comingSoon, .unavailable: false
                            }
                            switch model.entitlement {
                            case .base: return isAvailable
                            case .pro: return false
                            }
                        }
                        resolvedModelId = (firstBaseModel ?? process.usExaminationNeuralModelDefault!).id
                    }
                    let settings = SettingsAI(
                        transcriberType: storedSettings?.transcriberType ?? .whisperKit,
                        transcriptParserType: storedSettings?.transcriptParserType
                            ?? (process.examinationNeuralModelFactory!.isFoundationModelsAvailable ? .foundationModels : .server),
                        selectedNeuralModelId: resolvedModelId,
                        isMarkdown: storedSettings?.isMarkdown ?? false,
                        temperature: storedSettings?.temperature,
                        maxTokens: storedSettings?.maxTokens,
                    )
                    if settings != storedSettings {
                        try await settingsRepository.saveSettings(
                            settings,
                        )
                    }
                    process.initialSettingsAI = settings
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Stored user settings",
                run: { @MainActor (process: InitializationProcess) async throws in
                    let repository = process.userSettingsRepository!
                    process.initialUserSettings = try await UserSettings(
                        email: repository.getUserEmail(),
                        isRecommendationsIncluded: repository.getIsRecommendationsIncluded(),
                        isPhotoRemarks: repository.getIsPhotoRemarks(),
                        isDescriptionRemarks: repository.getIsDescriptionRemarks(),
                        isRemarksVisible: repository.getIsRemarksVisible(),
                    )
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Initial navigation",
                run: { @MainActor (process: InitializationProcess) async throws in
                    process.initialRoute = try await Coordinator.initialRoute(
                        for: InitialNavigationContext(
                            applicationConfig: process.applicationConfig!,
                            isOnBoardingCompleted: process.sharedRepository!.isOnBoardingCompleted(),
                            selectedUSExaminationTypeId: process.ultrasoundReportRepository!.getSelectedExaminationTypeId(),
                            acceptedLegalDocumentDate: process.sharedRepository!.getAcceptedLegalDocumentDate(),
                            conclusionsCount: process.initialUltrasoundReportsCount!,
                            subscriptionStatus: process.initialSubscriptionStatus,
                        ),
                    )
                },
            ),
        ],
    )
}
