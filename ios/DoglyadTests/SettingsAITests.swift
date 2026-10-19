import Combine
@testable import Doglyad
import DoglyadDatabase
import DoglyadSpeech
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct SettingsAITests {
    @Test(
        arguments: TranscriberType.allCases,
    )
    func transcriberChoiceSelectsTheRequestedEngineWithoutRecording(
        transcriber: TranscriberType,
    ) async throws {
        let locale = Locale(
            identifier: "en",
        )
        let isSupported: Bool = switch transcriber {
        case .whisperKit:
            true
        case .speechAnalyzer:
            if #available(iOS 26.0, *) {
                await DSpeechControllerAnalyzer.isSupported(
                    locale: locale,
                )
            } else {
                false
            }
        case .sfSpeechRecognizer:
            DSpeechControllerSFSpeechRecognizer.isSupported(
                locale: locale,
            )
        }
        let makeController = {
            try await DSpeechFactory.make(
                engine: transcriber.speechEngine,
                locale: locale,
                contextualStrings: [],
                lexiconLocalization: VoiceLocalizationTestSupport.speech(
                    locale: locale,
                ),
            )
        }
        guard isSupported else {
            await #expect(
                throws: DSpeechError.self,
            ) { try await makeController() }
            return
        }
        let controller = try await makeController()
        switch transcriber {
        case .whisperKit:
            #expect(
                controller is DSpeechControllerWhisperKit,
            )
        case .speechAnalyzer:
            if #available(iOS 26.0, *) {
                #expect(
                    controller is DSpeechControllerAnalyzer,
                )
            }
        case .sfSpeechRecognizer:
            #expect(
                controller is DSpeechControllerSFSpeechRecognizer,
            )
        }
        #expect(
            controller.text == nil,
        )
        #expect(
            controller.lastTranscript == nil,
        )
    }

    @Test(
        arguments: [TranscriberType?.none, .some(
            .speechAnalyzer,
        ), .some(
            .sfSpeechRecognizer,
        )],
    )
    func transcriberListOffersOnlyTheAvailableAppleEngineAndWhisperKit(
        appleTranscriber: TranscriberType?,
    ) async {
        let container = DependencyContainer.previewable
        var selected: TranscriberType?
        let model = SelectTranscriberViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            arguments: SelectTranscriberArguments(
                currentValue: .whisperKit,
                onSelected: { selected = $0 },
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: { container.initialSettingsAI },
            onRequestCountIncremented: {},
            getAvailableAppleEngine: { _ in appleTranscriber?.speechEngine },
        )
        model.onInit()
        await model.lastTask?.value
        switch appleTranscriber {
        case .speechAnalyzer:
            #expect(
                model.options == [.speechAnalyzer, .whisperKit],
            )
            model.onSelect(
                .sfSpeechRecognizer,
            )
        case .sfSpeechRecognizer:
            #expect(
                model.options == [.sfSpeechRecognizer, .whisperKit],
            )
            model.onSelect(
                .speechAnalyzer,
            )
        case .none, .whisperKit:
            #expect(
                model.options == [.whisperKit],
            )
            model.onSelect(
                .speechAnalyzer,
            )
        }
        #expect(
            selected == nil,
        )
        let choice = appleTranscriber ?? .whisperKit
        model.onSelect(
            choice,
        )
        #expect(
            selected == choice,
        )
    }

    @Test(
        arguments: TranscriberType.allCases,
        TranscriptParserType.allCases,
    )
    func speechChoicesSurviveRepositoryReloadAndReportStorage(
        transcriber: TranscriberType,
        parser: TranscriptParserType,
    ) async throws {
        let database = SettingsAITestDatabase()
        let settings = SettingsAI(
            transcriberType: transcriber,
            transcriptParserType: parser,
            selectedNeuralModelId: "test/report-model",
            isMarkdown: true,
            temperature: 0.2,
            maxTokens: 1024,
        )
        try await SettingsAIRepository(
            database: database,
        ).saveSettings(
            settings,
        )
        let restored = try await SettingsAIRepository(
            database: database,
        ).getSettings()
        #expect(
            restored == settings,
        )
        #expect(
            SettingsAI.fromDB(
                settings.toDB(),
            ) == settings,
        )
    }

    @Test
    func malformedSettingsAreReportedAndFailedEncodingPreservesPreviousSettings() async throws {
        let database = SettingsAITestDatabase()
        let repository = SettingsAIRepository(
            database: database,
        )
        #expect(
            try await repository.getSettings() == nil,
        )
        database.data = Data(
            "{invalid".utf8,
        )
        await #expect(
            throws: DecodingError.self,
        ) { try await repository.getSettings() }
        let settings = SettingsAI(
            selectedNeuralModelId: "model",
            isMarkdown: false,
            temperature: 0.2,
            maxTokens: 1000,
        )
        try await repository.saveSettings(
            settings,
        )
        let previous = database.data
        let invalid = SettingsAI(
            transcriberType: .sfSpeechRecognizer,
            transcriptParserType: .foundationModels,
            selectedNeuralModelId: "model",
            isMarkdown: true,
            temperature: .nan,
            maxTokens: 2000,
        )
        await #expect(
            throws: EncodingError.self,
        ) { try await repository.saveSettings(
            invalid,
        ) }
        #expect(
            database.data == previous,
        )
        #expect(
            try await repository.getSettings() == settings,
        )
        let reportSettings = settings.toDB()
        reportSettings.transcriptParserType = "unknown"
        #expect(
            SettingsAI.fromDB(
                reportSettings,
            ).transcriptParserType == .server,
        )
    }

    @Test
    func sheetEditsAreSavedTogetherAndFailedSaveKeepsEditsAndRootSettings() async throws {
        let base = DependencyContainer.previewable
        let repository = SettingsAITestRepository()
        let container = makeStateTestContainer(
            reportRepository: base.ultrasoundReportRepository,
            draftRepository: base.ultrasoundDraftRepository,
            settingsAIRepository: repository,
        )
        let root = UltrasoundRootViewModel(
            container: container,
        )
        let previous = root.storedSettingsAI
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        let model = SettingsAIViewModel(
            container: container,
            getInitialNeuralModel: { container.usExaminationNeuralModelDefault },
            getInitialIsMarkdown: { root.isMarkdown },
            getInitialTemperature: { root.temperature },
            getInitialMaxTokens: { root.maxTokens },
            messager: DMessager(),
            router: router,
            getSubscriptionStatus: { makeStatus(
                .pro,
            ) },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: { root.storedSettingsAI },
            onRequestCountIncremented: {},
            onNeuralModelSelected: { _ in },
            onSettingsSaved: { transcriber, parser, markdown, temperature, tokens in
                try await root.saveSettingsAI(
                    transcriberType: transcriber,
                    transcriptParserType: parser,
                    isMarkdown: markdown,
                    temperature: temperature,
                    maxTokens: tokens,
                )
            },
        )
        model.coordinator.screen(
            .settingsAI,
        )
        model.onTapTranscriber()
        let transcriberArguments = try #require(
            router.sheet?.arguments as? SelectTranscriberArguments,
        )
        transcriberArguments.onSelected(
            .sfSpeechRecognizer,
        )
        model.coordinator.dismissSheet()
        model.onTapTranscriptParser()
        let parserArguments = try #require(
            router.sheet?.arguments as? SelectTranscriptParserArguments,
        )
        parserArguments.onSelected(
            .server,
        )
        model.coordinator.dismissSheet()
        #expect(
            repository.saveCount == 0,
        )
        model.isMarkdown = true
        repository.isSaveFailing = true
        model.onTapSave()
        await model.lastTask?.value
        #expect(
            model.state is SettingsAIFailedState,
        )
        #expect(
            model.transcriberType == .sfSpeechRecognizer,
        )
        #expect(
            model.transcriptParserType == .server,
        )
        #expect(
            root.storedSettingsAI == previous,
        )
        #expect(
            repository.settings == nil,
        )
        repository.isSaveFailing = false
        model.onTapSave()
        await model.lastTask?.value
        #expect(
            repository.settings == root.storedSettingsAI,
        )
        #expect(
            root.transcriberType == .sfSpeechRecognizer,
        )
        #expect(
            root.transcriptParserType == .server,
        )
        #expect(
            root.isMarkdown,
        )
    }

    @Test(
        arguments: [false, true],
        [false, true],
    )
    func missingDatabaseSpeechChoicesUseDefaultsWithoutReplacingPresentValues(
        isTranscriberStored: Bool,
        isParserStored: Bool,
    ) {
        let database = SettingsAIDB(
            transcriberType: isTranscriberStored ? TranscriberType.sfSpeechRecognizer.rawValue : nil,
            transcriptParserType: isParserStored ? TranscriptParserType.foundationModels.rawValue : nil,
            selectedNeuralModelId: "model",
            isMarkdown: true,
            temperature: 0.7,
            maxTokens: 1500,
        )
        let settings = SettingsAI.fromDB(
            database,
        )
        #expect(
            settings.transcriberType == (isTranscriberStored ? .sfSpeechRecognizer : .whisperKit),
        )
        #expect(
            settings.transcriptParserType == (isParserStored ? .foundationModels : .server),
        )
        #expect(
            settings.isMarkdown,
        )
        #expect(
            settings.temperature == 0.7,
        )
        #expect(
            settings.maxTokens == 1500,
        )
    }

    @Test(
        arguments: [String?.none, .some (
            "",
        ), .some (
            " \n ",
        ), .some (
            "unknown",
        )],
    )
    func invalidDatabaseSpeechChoicesFallBackWithoutThrowing(
        rawValue: String?,
    ) {
        let database = SettingsAIDB(
            transcriberType: rawValue,
            transcriptParserType: rawValue,
            selectedNeuralModelId: "model",
            temperature: 0.5,
            maxTokens: 1500,
        )
        let settings = SettingsAI.fromDB(
            database,
        )
        #expect(
            settings.transcriberType == .whisperKit,
        )
        #expect(
            settings.transcriptParserType == .server,
        )
        #expect(
            settings.temperature == 0.5,
        )
        #expect(
            settings.maxTokens == 1500,
        )
        database.transcriberType = "  sfSpeechRecognizer \n"
        database.transcriptParserType = "  foundationModels \n"
        let restored = SettingsAI.fromDB(
            database,
        )
        #expect(
            restored.transcriberType == .sfSpeechRecognizer,
        )
        #expect(
            restored.transcriptParserType == .foundationModels,
        )
    }

    @Test(
        arguments: [SubscriptionType?.none, .some (
            .base,
        ), .some (
            .pro,
        )],
        [SubscriptionFeatureAvailability.unavailable, .offered, .available],
    )
    func reportSettingsRequireProWhileSpeechSettingsRemainEditable(
        type: SubscriptionType?,
        availability: SubscriptionFeatureAvailability,
    ) async {
        let container = DependencyContainer.previewable
        let stored = SettingsAI(
            transcriberType: .whisperKit,
            transcriptParserType: .server,
            selectedNeuralModelId: "model",
            isMarkdown: true,
            temperature: 0.7,
            maxTokens: 1500,
        )
        let subscription = SubscriptionRootViewModel(
            container: container,
            getStoredSettingsAI: { stored },
        )
        subscription.update(
            status: type.map { makeStatus(
                $0,
                availability: availability,
            ) },
        )
        var saved: SettingsAI?
        let model = SettingsAIViewModel(
            container: container,
            getInitialNeuralModel: { container.usExaminationNeuralModelDefault },
            getInitialIsMarkdown: { stored.isMarkdown },
            getInitialTemperature: { stored.temperature! },
            getInitialMaxTokens: { stored.maxTokens! },
            messager: DMessager(),
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { subscription.status },
            observeSubscriptionStatus: { subscription.observeStatus(
                $0,
            ) },
            onSubscriptionStatusUpdated: { subscription.update(
                status: $0,
            ) },
            getSettingsAI: { subscription.resolveSettingsAI() },
            onRequestCountIncremented: {},
            onNeuralModelSelected: { _ in },
            onSettingsSaved: { transcriber, parser, markdown, temperature, tokens in
                saved = SettingsAI(
                    transcriberType: transcriber,
                    transcriptParserType: parser,
                    selectedNeuralModelId: stored.selectedNeuralModelId,
                    isMarkdown: markdown,
                    temperature: temperature,
                    maxTokens: tokens,
                )
            },
        )
        model.coordinator.screen(
            .settingsAI,
        )
        let isEnabled = switch type {
        case .pro:
            switch availability {
            case .available: true
            case .offered, .unavailable: false
            }
        case .base, .none:
            false
        }
        #expect(
            model.isReportGenerationSettingsEnabled == isEnabled,
        )
        #expect(
            model.reportGenerationSettingsAvailability == (isEnabled ? .available : .offered),
        )
        model.toggleIsMarkdown()
        #expect(
            model.isMarkdown == !isEnabled,
        )
        model.isMarkdown = false
        model.temperatureTextController.setText(
            isEnabled ? "0.8" : "",
        )
        model.maxTokensTextController.setText(
            isEnabled ? "2048" : "0",
        )
        model.transcriberType = .sfSpeechRecognizer
        model.onTapSave()
        await model.lastTask?.value
        #expect(
            saved?.transcriberType == .sfSpeechRecognizer,
        )
        #expect(
            saved?.transcriptParserType == .server,
        )
        #expect(
            saved?.isMarkdown == (isEnabled ? false : stored.isMarkdown),
        )
        #expect(
            saved?.temperature == (isEnabled ? 0.8 : stored.temperature),
        )
        #expect(
            saved?.maxTokens == (isEnabled ? 2048 : stored.maxTokens),
        )
        let effective = subscription.resolveSettingsAI()
        #expect(
            effective.transcriberType == stored.transcriberType,
        )
        #expect(
            effective.transcriptParserType == stored.transcriptParserType,
        )
        #expect(
            effective.isMarkdown == isEnabled,
        )
        #expect(
            effective.temperature == (isEnabled ? stored.temperature : container.applicationConfig.ultrasound.neuralModel.temperature),
        )
        #expect(
            effective.maxTokens == (isEnabled ? stored.maxTokens : container.applicationConfig.ultrasound.neuralModel.maxTokens),
        )
    }

    @Test
    func losingProRemovesFocusAndUpdatesControlAvailabilityWithoutLosingSpeechChoices() {
        let container = DependencyContainer.previewable
        let subscription = SubscriptionRootViewModel(
            container: container,
        )
        subscription.update(
            status: makeStatus(
                .pro,
            ),
        )
        let model = SettingsAIViewModel(
            container: container,
            getInitialNeuralModel: { container.usExaminationNeuralModelDefault },
            getInitialIsMarkdown: { false },
            getInitialTemperature: { 0.2 },
            getInitialMaxTokens: { 1024 },
            messager: DMessager(),
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { subscription.status },
            observeSubscriptionStatus: { subscription.observeStatus(
                $0,
            ) },
            onSubscriptionStatusUpdated: { subscription.update(
                status: $0,
            ) },
            getSettingsAI: { container.initialSettingsAI },
            onRequestCountIncremented: {},
            onNeuralModelSelected: { _ in },
            onSettingsSaved: { _, _, _, _, _ in },
        )
        model.transcriberType = .sfSpeechRecognizer
        model.transcriptParserType = .server
        model.onFocusChanged(
            .temperature,
        )
        #expect(
            model.focus == .temperature,
        )
        subscription.update(
            status: makeStatus(
                .base,
                availability: .available,
            ),
        )
        #expect(
            model.focus == nil,
        )
        #expect(
            !model.isReportGenerationSettingsEnabled,
        )
        #expect(
            model.reportGenerationSettingsAvailability == .offered,
        )
        #expect(
            model.transcriberType == .sfSpeechRecognizer,
        )
        #expect(
            model.transcriptParserType == .server,
        )
        subscription.update(
            status: makeStatus(
                .pro,
            ),
        )
        #expect(
            model.isReportGenerationSettingsEnabled,
        )
        #expect(
            model.reportGenerationSettingsAvailability == .available,
        )
    }

    @Test(
        arguments: [false, true],
    )
    func settingsAndScanOpenAISettingsWithoutAProSubscription(
        isScan: Bool,
    ) {
        let container = DependencyContainer.previewable
        for status in [nil, makeStatus(
            .base,
            availability: .offered,
        ), makeStatus(
            .base,
            availability: .unavailable,
        )] {
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            )
            if isScan {
                let model = ScanViewModel(
                    container: container,
                    messager: DMessager(),
                    router: router,
                    getSubscriptionStatus: { status },
                    observeSubscriptionStatus: { _ in AnyCancellable {} },
                    onSubscriptionStatusUpdated: { _ in },
                    getSettingsAI: { container.initialSettingsAI },
                    onRequestCountIncremented: {},
                    observeExaminationChanges: { _ in AnyCancellable {} },
                    getSelectedTemplate: { nil },
                    onTemplateSelected: { _ in },
                    onTemplateReset: {},
                    getNeuralModel: { container.usExaminationNeuralModelDefault },
                    onNeuralModelSelected: { _ in },
                )
                model.onTapSettingsAI()
            } else {
                let model = SettingsViewModel(
                    container: container,
                    router: router,
                    getSubscriptionStatus: { status },
                    observeSubscriptionStatus: { _ in AnyCancellable {} },
                    onSubscriptionStatusUpdated: { _ in },
                    getSettingsAI: { container.initialSettingsAI },
                    onRequestCountIncremented: {},
                )
                model.onTapSettingsAI()
            }
            let expected = DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            )
            expected.push(
                route: RouteScreen(
                    type: .settingsAI,
                ),
            )
            #expect(
                router.path == expected.path,
            )
            #expect(
                router.sheet == nil,
            )
        }
    }

    @Test
    func unavailableFoundationModelsCannotBeSelectedAndServerRemainsSelectable() {
        let container = DependencyContainer.previewable
        var selected: TranscriptParserType?
        let model = SelectTranscriptParserViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            arguments: SelectTranscriptParserArguments(
                currentValue: .server,
                onSelected: { selected = $0 },
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: { container.initialSettingsAI },
            onRequestCountIncremented: {},
        )
        #expect(
            model.isSelectionEnabled(
                for: .foundationModels,
            ) == container.examinationNeuralModelFactory.isFoundationModelsAvailable,
        )
        #expect(
            model.isSelectionEnabled(
                for: .server,
            ),
        )
        if !model.isFoundationModelsAvailable {
            model.onSelect(
                .foundationModels,
            )
            #expect(
                selected == nil,
            )
        }
        model.onSelect(
            .server,
        )
        #expect(
            selected == .server,
        )
    }

    private func makeStatus(
        _ type: SubscriptionType,
        availability: SubscriptionFeatureAvailability = .available,
    ) -> SubscriptionStatus {
        SubscriptionStatus(
            type: type,
            entitlement: SubscriptionEntitlement(
                requestCountPerDay: 20,
                formCompletionViaMicrophone: .available,
                sendingReportByEmail: .available,
                settingsAI: availability,
            ),
            availableCountPerDay: 20,
        )
    }
}

private final class SettingsAITestDatabase: DDatabaseSettingsAIProtocol {
    var data: Data?

    func getSettingsAIData() -> Data? { data }

    func setSettingsAIData(
        _ value: Data,
    ) { data = value }
}

private final class SettingsAITestRepository: SettingsAIRepositoryProtocol {
    var settings: SettingsAI?
    var isSaveFailing = false
    var saveCount = 0

    func getSettings() async throws -> SettingsAI? { settings }

    func saveSettings(
        _ settings: SettingsAI,
    ) async throws {
        saveCount += 1
        if isSaveFailing { throw CocoaError(
            .fileWriteUnknown,
        ) }
        self.settings = settings
    }
}
