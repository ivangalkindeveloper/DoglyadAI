import DependencyInitializer
import DoglyadNeuralModel
import Foundation

extension InitializationProcess {
    static let stepsTier4 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "Ultrasound examination types",
                run: { (process: InitializationProcess) async throws in
                    let url = await process.environment!.baseUrl.appendingPathComponent("ultrasound_examination_types")
                    let usExaminationTypes: [USExaminationType] = try await process.httpClient!.get(url: url)
                    if usExaminationTypes.isEmpty {
                        throw InitializationError.usExaminationTypesEmpty
                    }

                    await MainActor.run {
                        process.usExaminationTypes = usExaminationTypes
                        process.usExaminationTypesById = Dictionary(
                            uniqueKeysWithValues: usExaminationTypes.map { ($0.id, $0) }
                        )
                        process.usExaminationTypeDefault = usExaminationTypes.first!
                    }
                }
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Ultrasound examination neural models",
                run: { (process: InitializationProcess) async throws in
                    let url = await process.environment!.baseUrl.appendingPathComponent("ultrasound_examination_neural_models")
                    let usExaminationNeuralModels: [USExaminationNeuralModel] = try await process.httpClient!.get(url: url)
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
                title: "Ultrasound examination contextual strings",
                run: { (process: InitializationProcess) async throws in
                    let url = await process.environment!.baseUrl.appendingPathComponent("ultrasound_examination_contextual_strings")
                    // Strings may be empty — that is a valid state, so unlike types and
                    // models we do not check them for emptiness.
                    let usExaminationContextualStrings: USExaminationContextualStrings = try await process.httpClient!.get(url: url)

                    await MainActor.run {
                        process.usExaminationContextualStrings = usExaminationContextualStrings
                    }
                }
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Local ultrasound examination neural model",
                run: { (process: InitializationProcess) in
                    let config = await process.applicationConfig!.ultrasound.examinationNeuralModel
                    // The locale is needed for more than the prompt: the factory uses it to
                    // decide whether the system model knows the dictation language.
                    let locale = Locale.current
                    guard let prompt = config.getPrompt(for: locale) else {
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
                    let count = await process.ultrasoundConclusionRepository!.getConclusionsCount()
                    await MainActor.run {
                        process.initialUltraSoundConclusionsCount = count
                    }
                }
            ),
        ]
    )
}
