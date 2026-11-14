@testable import DependencyInitializer
@testable import Doglyad
import Foundation
import Testing

@MainActor
struct StoredStateInitializationTests {
    init() {}

    @Test(
        arguments: [false, true],
    )
    func settingsArePublishedOnlyAfterSuccessfulPersistence(
        isSaveFailed: Bool,
    ) async throws {
        let base = DependencyContainer.previewable
        let repository = InitializationTestSettingsRepository(
            isSaveFailed: isSaveFailed,
        )
        let process = InitializationProcess()
        process.settingsAIRepository = repository
        process.usExaminationNeuralModels = base.usExaminationNeuralModels
        process.usExaminationNeuralModelsById = base.usExaminationNeuralModelsById
        process.usExaminationNeuralModelDefault = base.usExaminationNeuralModelDefault
        process.examinationNeuralModelFactory = base.examinationNeuralModelFactory
        let stepSet: StepSet<InitializationProcess>
        switch InitializationProcess.stepsTier5.kind {
        case let .async(
            steps,
        ):
            let step = try #require(
                steps.first {
                    $0.title == "Stored AI settings"
                },
            )
            stepSet = StepSet(
                async: [step],
            )
        case .sync:
            Issue.record(
                "Settings restoration must support asynchronous storage",
            )
            return
        }
        var failedStep: String?
        var isNextTierStarted = false
        await DependencyInitializer<InitializationProcess, DependencyContainer>(
            createProcess: {
                process
            },
            stepSets: [stepSet, StepSet(
                sync: [SyncInitializationStep<InitializationProcess>(
                    title: "After restoration",
                    run: { _ in
                        isNextTierStarted = true
                    },
                )],
            )],
            onError: { _, _, step, _ in
                failedStep = step.title
            },
        ).run()
        #expect(
            repository.saveCount == 1,
        )
        if isSaveFailed {
            #expect(
                failedStep == "Stored AI settings",
            )
            #expect(
                process.initialSettingsAI == nil,
            )
            #expect(
                !isNextTierStarted,
            )
        } else {
            #expect(
                failedStep == nil,
            )
            #expect(
                isNextTierStarted,
            )
            #expect(
                process.initialSettingsAI == repository.savedSettings,
            )
        }
    }
}

@MainActor
private final class InitializationTestSettingsRepository: SettingsAIRepositoryProtocol {
    let isSaveFailed: Bool
    private(set) var savedSettings: SettingsAI?
    private(set) var saveCount = 0

    init(
        isSaveFailed: Bool,
    ) {
        self.isSaveFailed = isSaveFailed
    }

    func getSettings() async throws -> SettingsAI? {
        nil
    }

    func saveSettings(
        _ settings: SettingsAI,
    ) async throws {
        saveCount += 1
        if isSaveFailed {
            throw CocoaError(
                .fileWriteUnknown,
            )
        }
        savedSettings = settings
    }
}
