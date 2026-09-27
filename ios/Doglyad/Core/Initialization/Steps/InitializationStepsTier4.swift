import DependencyInitializer
import DoglyadNetwork
import DoglyadNeuralModel
import Foundation

extension InitializationProcess {
    static let stepsTier4 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "Ultrasound examination types",
                run: { (process: InitializationProcess) async throws in
                    let languageCode = await process.language!.currentCode
                    let usExaminationTypeGroups: [USExaminationTypeGroup] = try await process.httpClient!.get(
                        endPoint: "/ultrasound/examination_types",
                        headers: [DHttpHeader.acceptLanguage: languageCode]
                    )
                    guard let usExaminationTypeDefault = usExaminationTypeGroups.lazy
                        .compactMap(\.examinationTypes.first)
                        .first
                    else {
                        throw InitializationError.usExaminationTypesEmpty
                    }
                    let usExaminationTypesById = Dictionary(
                        uniqueKeysWithValues: usExaminationTypeGroups
                            .flatMap(\.examinationTypes)
                            .map { ($0.id, $0) }
                    )

                    await MainActor.run {
                        process.usExaminationTypeGroups = usExaminationTypeGroups
                        process.usExaminationTypesById = usExaminationTypesById
                        process.usExaminationTypeDefault = usExaminationTypeDefault
                    }
                }
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Ultrasound examination neural models",
                run: { (process: InitializationProcess) async throws in
                    let languageCode = await process.language!.currentCode
                    let usExaminationNeuralModels: [USExaminationNeuralModel] = try await process.httpClient!.get(
                        endPoint: "/ultrasound/examination_neural_models",
                        headers: [DHttpHeader.acceptLanguage: languageCode]
                    )
                    if usExaminationNeuralModels.isEmpty {
                        throw InitializationError.usExaminationNeuralModelsEmpty
                    }

                    await MainActor.run {
                        process.usExaminationNeuralModels = usExaminationNeuralModels
                        process.usExaminationNeuralModelsById = Dictionary(
                            uniqueKeysWithValues: usExaminationNeuralModels.map { ($0.id, $0) }
                        )
                        process.usExaminationNeuralModelDefault = usExaminationNeuralModels.first!
                    }
                }
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Local ultrasound examination neural model",
                run: { (process: InitializationProcess) in
                    let config = await process.applicationConfig!.ultrasound.examinationNeuralModel
                    let locale = await process.language!.currentLocale
                    let prompt = config.prompt
                    guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw InitializationError.examinationNeuralModelPromptEmpty
                    }

                    let parameters = DExaminationGenerationParameters(
                        temperature: config.temperature,
                        maxTokens: config.maxTokens,
                        maxContextTokens: config.maxContextTokens
                    )

                    await MainActor.run {
                        process.examinationNeuralModelFactory = DExaminationNeuralModelFactory(
                            locale: locale,
                            systemPrompt: prompt,
                            parameters: parameters
                        )
                    }
                }
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Subscription",
                run: { (process: InitializationProcess) async throws in
                    let configEntitlements = await process.applicationConfig!.entitlements
                    let status = try await process.subscriptionRepository!.fetchStatus(
                        configEntitlements: configEntitlements
                    )
                    await MainActor.run {
                        process.initialSubscriptionStatus = status
                    }
                }
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Initial ultrasound conclusions",
                run: { (process: InitializationProcess) async in
                    let count = await process.ultrasoundReportRepository!.getReportsCount()
                    await MainActor.run {
                        process.initialUltrasoundReportsCount = count
                    }
                }
            ),
        ]
    )
}
