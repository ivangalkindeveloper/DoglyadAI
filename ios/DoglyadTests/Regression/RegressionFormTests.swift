#if DEBUG && DOGLYAD_REGRESSION
    import Combine
    @testable import Doglyad
    import DoglyadSpeech
    @testable import DoglyadUI
    import Foundation
    import Router
    import UIKit
    import XCTest

    @MainActor
    final class RegressionFormTests: XCTestCase {
        func testRecoveryIgnoresLateResponseAfterLeavingAndRetainsFailedInput() async throws {
            let container = DependencyContainer.previewable
            for shouldFail in [false, true] {
                let navigation = router(
                    .subscriptionRecovery,
                )
                var completion: CheckedContinuation<SubscriptionStatus?, Error>?
                var statusUpdates = 0
                let model = SubscriptionRecoveryViewModel(
                    container: container,
                    router: navigation,
                    getSubscriptionStatus: {
                        nil
                    },
                    observeSubscriptionStatus: { _ in
                        AnyCancellable {}
                    },
                    onSubscriptionStatusUpdated: { _ in
                        statusUpdates += 1
                    },
                    getSettingsAI: {
                        container.initialSettingsAI
                    },
                    onRefreshSubscriptionStatus: {},
                    arguments: nil,
                    createRecoveryKey: {
                        XCTFail(
                            "Restoration cannot create a new key",
                        )
                        return ""
                    },
                    recover: { _ in
                        try await withCheckedThrowingContinuation {
                            completion = $0
                        }
                    },
                )
                model.recoveryTextController.setText(
                    "retained-key",
                )
                model.onTapRestore()
                let operation = model.operationTask
                for _ in 0 ..< 100 {
                    if completion != nil {
                        break
                    }
                    try await Task.sleep(
                        for: .milliseconds(
                            10,
                        ),
                    )
                }
                let pending = try XCTUnwrap(
                    completion,
                )
                XCTAssertTrue(
                    model.isProcessing,
                )
                model.onTapBack()
                model.onDisappear()
                let closedState = model.state
                if shouldFail {
                    pending.resume(
                        throwing: URLError(
                            .networkConnectionLost,
                        ),
                    )
                } else {
                    pending.resume(
                        returning: ModulePreviewFactory.subscription,
                    )
                }
                await operation?.value
                XCTAssertTrue(
                    model.state === closedState,
                )
                XCTAssertTrue(
                    navigation.path.isEmpty,
                )
                XCTAssertEqual(
                    statusUpdates,
                    0,
                )
                XCTAssertEqual(
                    model.recoveryTextController.text,
                    "retained-key",
                )
            }
        }

        func testYooKassaRestorationOpensRecoveryWithoutStartingAppleOrPaymentOperations() async {
            let container = DependencyContainer.previewable
            let navigation = DRouter(
                initialRoute: RouteScreen(
                    type: .paywall,
                ),
            )
            var restoreCalls = 0
            var purchaseCalls = 0
            let model = PaywallViewModel(
                container: container,
                router: navigation,
                getSubscriptionStatus: {
                    nil
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: nil,
                purchase: { _ in
                    purchaseCalls += 1
                    return .cancelled
                },
                restorePurchases: {
                    restoreCalls += 1
                    return nil
                },
                checkPurchase: {
                    .pending
                },
            )
            model.preparePreview(
                state: ModulePreviewFactory.paywallContent,
            )
            XCTAssertEqual(
                navigation.path.count,
                0,
            )
            model.onTapRestore()
            XCTAssertEqual(
                navigation.path.count,
                1,
            )
            XCTAssertTrue(
                model.state === ModulePreviewFactory.paywallContent,
            )
            await Task.yield()
            XCTAssertEqual(
                restoreCalls,
                0,
            )
            XCTAssertEqual(
                purchaseCalls,
                0,
            )
            navigation.pop()
            XCTAssertEqual(
                navigation.path.count,
                0,
            )
            XCTAssertTrue(
                model.isContinueEnabled,
            )
        }

        func testModelAvailabilityAndSubscriptionGateEverySelection() async {
            let container = DependencyContainer.previewable
            let original = container.usExaminationNeuralModels[
                0,
            ]
            for tier in [nil, .base, .pro] as [SubscriptionType?] {
                let status = tier.map {
                    ManageSubscriptionPreviewFactory.makeStatus(
                        source: .yookassa,
                        type: $0,
                    )
                }
                for entitlement in [SubscriptionType.base, .pro] {
                    for availability in [USExaminationNeuralModelAccessibility.available, .unavailable, .comingSoon] {
                        let candidate = USExaminationNeuralModel(
                            id: original.id,
                            title: original.title,
                            entitlement: entitlement,
                            accessibility: availability,
                            contextLength: original.contextLength,
                            description: original.description,
                        )
                        var selected: [USExaminationNeuralModel] = []
                        let model = SelectNeuralModelViewModel(
                            container: container,
                            router: router(),
                            arguments: SelectNeuralModelArguments(
                                onSelected: {
                                    selected.append(
                                        $0,
                                    )
                                },
                            ),
                            getSubscriptionStatus: {
                                status
                            },
                            observeSubscriptionStatus: { _ in
                                AnyCancellable {}
                            },
                            onSubscriptionStatusUpdated: { _ in },
                            getSettingsAI: {
                                container.initialSettingsAI
                            },
                            onRefreshSubscriptionStatus: {},
                        )
                        XCTAssertEqual(
                            model.isSelectionEnabled(
                                for: candidate,
                            ),
                            availability == .available,
                        )
                        XCTAssertEqual(
                            model.isComingSoonBadgeVisible(
                                for: candidate,
                            ),
                            availability == .comingSoon,
                        )
                        XCTAssertEqual(
                            model.isProBadgeVisible(
                                for: candidate,
                            ),
                            entitlement == .pro && tier != .pro,
                        )
                        model.onModelTap(
                            candidate,
                        )
                        for _ in 0 ..< 100 {
                            if model.state is SelectNeuralModelContentState {
                                break
                            }
                            try? await Task.sleep(
                                for: .milliseconds(
                                    10,
                                ),
                            )
                        }
                        let allowed = availability == .available && (entitlement == .base || tier == .pro)
                        XCTAssertEqual(
                            selected,
                            allowed ? [candidate] : [],
                        )
                        XCTAssertEqual(
                            model.currentValue,
                            allowed ? candidate : nil,
                        )
                    }
                }
            }
        }

        func testParserAvailabilityRefreshesOnForegroundAndBlocksUnavailableSelection() async {
            let container = DependencyContainer.previewable
            var available = true
            var selected: TranscriptParserType?
            let model = SelectTranscriptParserViewModel(
                container: container,
                router: router(),
                arguments: SelectTranscriptParserArguments(
                    currentValue: .server,
                    onSelected: {
                        selected = $0
                    },
                ),
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                getFoundationModelsAvailability: {
                    available
                },
            )
            model.onInit()
            XCTAssertTrue(
                model.isSelectionEnabled(
                    for: .foundationModels,
                ),
            )
            model.onSelect(
                .foundationModels,
            )
            XCTAssertEqual(
                selected,
                .foundationModels,
            )
            selected = nil
            available = false
            NotificationCenter.default.post(
                name: UIApplication.didBecomeActiveNotification,
                object: nil,
            )
            for _ in 0 ..< 100 {
                if !model.isFoundationModelsAvailable {
                    break
                }
                try? await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTAssertFalse(
                model.isFoundationModelsAvailable,
            )
            model.onSelect(
                .foundationModels,
            )
            XCTAssertNil(
                selected,
            )
            model.onSelect(
                .server,
            )
            XCTAssertEqual(
                selected,
                .server,
            )
            available = true
            NotificationCenter.default.post(
                name: UIApplication.didBecomeActiveNotification,
                object: nil,
            )
            for _ in 0 ..< 100 {
                if model.isFoundationModelsAvailable {
                    break
                }
                try? await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTAssertTrue(
                model.isFoundationModelsAvailable,
            )
        }

        func testTranscriberAvailabilityRefreshesOnForegroundWithoutDuplicates() async {
            let container = DependencyContainer.previewable
            var engine: DSpeechEngine? = .speechAnalyzer
            var selected: TranscriberType?
            let model = SelectTranscriberViewModel(
                container: container,
                router: router(),
                arguments: SelectTranscriberArguments(
                    currentValue: .whisperKit,
                    onSelected: {
                        selected = $0
                    },
                ),
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                getAvailableAppleEngine: { _ in
                    engine
                },
            )
            model.onInit()
            await model.lastTask?.value
            XCTAssertEqual(
                model.options,
                [.speechAnalyzer, .whisperKit],
            )
            let changes: [(DSpeechEngine?, [TranscriberType])] = [(.sfSpeechRecognizer, [.sfSpeechRecognizer, .whisperKit]), (nil, [.whisperKit])]
            for (next, expected) in changes {
                engine = next
                NotificationCenter.default.post(
                    name: UIApplication.didBecomeActiveNotification,
                    object: nil,
                )
                for _ in 0 ..< 100 {
                    if model.options == expected {
                        break
                    }
                    try? await Task.sleep(
                        for: .milliseconds(
                            10,
                        ),
                    )
                }
                XCTAssertEqual(
                    model.options,
                    expected,
                )
                model.onSelect(
                    .speechAnalyzer,
                )
                XCTAssertNil(
                    selected,
                )
            }
            model.onSelect(
                .whisperKit,
            )
            XCTAssertEqual(
                selected,
                .whisperKit,
            )
        }

        func testScanRejectsInvalidRestoredFieldsAndPreservesFocusOrder() async throws {
            let container = DependencyContainer.previewable
            var started = 0
            let model = ScanViewModel(
                container: container,
                messager: DMessager(),
                router: router(),
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                observeExaminationChanges: { _ in
                    AnyCancellable {}
                },
                getSelectedTemplate: {
                    nil
                },
                onTemplateSelected: { _ in },
                onTemplateReset: {},
                getNeuralModel: {
                    container.usExaminationNeuralModelDefault
                },
                onNeuralModelSelected: { _ in },
                onStartReportGeneration: { _ in
                    started += 1
                    return ModulePreviewFactory.report
                },
            )
            model.preparePreview(
                state: ScanDefaultState(),
            )
            let config = container.applicationConfig.scan
            let fields: [(DTextFieldController, Int, ScanFocus, Bool)] = [
                (model.examinationNumberTextController, config.examinationNumberMaxLength, .examinationNumber, true),
                (model.patientNameTextController, config.patientNameMaxLength, .patientName, true),
                (model.patientComplaintsTextController, config.patientComplaintsMaxLength, .patientComplaints, false),
                (model.examinationDescriptionTextController, config.examinationDescriptionMaxLength, .examinationDescription, true),
            ]
            func validForm() {
                for (field, _, _, _) in fields {
                    field.restoreText(
                        "valid",
                    )
                }
                model.patientHeightCMTextController.restoreText(
                    "170",
                )
                model.patientWeightKGTextController.restoreText(
                    "65",
                )
            }
            for (field, maximum, focus, required) in fields {
                validForm()
                for length in [maximum - 1, maximum] {
                    field.restoreText(
                        String(
                            repeating: "я",
                            count: length,
                        ),
                    )
                    XCTAssertTrue(
                        field.validate(),
                        "Valid boundary for \(focus)",
                    )
                    XCTAssertNil(
                        model.firstInvalidFocus(),
                    )
                }
                field.restoreText(
                    String(
                        repeating: "я",
                        count: maximum + 1,
                    ),
                )
                model.onTapScan()
                XCTAssertEqual(
                    model.focus,
                    focus,
                )
                XCTAssertTrue(
                    model.state is ScanDefaultState,
                )
                field.clear()
                field.setText(
                    String(
                        repeating: "я",
                        count: maximum + 1,
                    ),
                )
                XCTAssertEqual(
                    field.text.count,
                    maximum,
                )
                field.clear()
                XCTAssertEqual(
                    field.validate(),
                    !required,
                )
                if required {
                    model.onTapScan()
                    XCTAssertEqual(
                        model.focus,
                        focus,
                    )
                }
            }
            let numbers: [(DTextFieldController, Int, ScanFocus)] = [
                (model.patientHeightCMTextController, config.patientHeightCMMaxLength, .patientHeightCM),
                (model.patientWeightKGTextController, config.patientWeightKGMaxLength, .patientWeightKG),
            ]
            for (field, maximum, focus) in numbers {
                validForm()
                for value in ["0", "-1", "abc", String(
                    repeating: "9",
                    count: maximum + 1,
                )] {
                    field.restoreText(
                        value,
                    )
                    model.onTapScan()
                    XCTAssertEqual(
                        model.focus,
                        focus,
                    )
                    XCTAssertTrue(
                        model.state is ScanDefaultState,
                    )
                }
                for value in ["", "0.1", String(
                    repeating: "9",
                    count: maximum,
                )] {
                    field.restoreText(
                        value,
                    )
                    XCTAssertTrue(
                        field.validate(),
                    )
                }
                field.clear()
                field.setText(
                    "12a3,5",
                )
                XCTAssertEqual(
                    field.text,
                    "123.5",
                )
            }
            validForm()
            let order: [ScanFocus] = [.examinationNumber, .patientName, .patientHeightCM, .patientWeightKG, .patientComplaints, .examinationDescription]
            model.onFocusChanged(
                order[
                    0,
                ],
            )
            for next in order.dropFirst() {
                model.onTapToolbarDown()
                XCTAssertEqual(
                    model.focus,
                    next,
                )
            }
            for previous in order.dropLast().reversed() {
                model.onTapToolbarUp()
                XCTAssertEqual(
                    model.focus,
                    previous,
                )
            }
            for next in order.dropFirst() {
                model.onSubmit()
                XCTAssertEqual(
                    model.focus,
                    next,
                )
            }
            model.onSubmit()
            XCTAssertNil(
                model.focus,
            )
            XCTAssertEqual(
                model.patientNameTextController.text,
                "valid",
            )
            try await Task.sleep(
                for: .milliseconds(
                    100,
                ),
            )
            XCTAssertEqual(
                started,
                0,
                "Invalid fields must never create a report job",
            )
        }

        func testTemplateBoundariesRejectWritesAndKeepFullContent() async throws {
            let container = DependencyContainer.previewable
            var saved: [USExaminationTemplate] = []
            let model = TemplateAddViewModel(
                container: container,
                router: router(
                    .templateAdd,
                ),
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                messager: DMessager(),
                onSaveTemplate: {
                    saved.append(
                        $0,
                    )
                },
            )
            model.preparePreview(
                state: TemplateAddDefaultState(),
            )
            let limits: [(DTextFieldController, Int, TemplateAddFocus)] = [
                (model.nameTextController, container.applicationConfig.templateAdd.nameMaxLength, .name),
                (model.templateTextController, container.applicationConfig.templateAdd.contentMaxLength, .content),
            ]
            for (field, maximum, focus) in limits {
                model.nameTextController.restoreText(
                    "Name",
                )
                model.templateTextController.restoreText(
                    "Content",
                )
                for value in ["", String(
                    repeating: "я",
                    count: maximum + 1,
                )] {
                    field.restoreText(
                        value,
                    )
                    model.onTapSave()
                    XCTAssertEqual(
                        model.focus,
                        focus,
                    )
                    XCTAssertTrue(
                        model.state is TemplateAddDefaultState,
                    )
                }
                for length in [maximum - 1, maximum] {
                    field.restoreText(
                        String(
                            repeating: "я",
                            count: length,
                        ),
                    )
                    XCTAssertTrue(
                        field.validate(),
                    )
                }
                field.clear()
                field.setText(
                    String(
                        repeating: "я",
                        count: maximum + 1,
                    ),
                )
                XCTAssertEqual(
                    field.text.count,
                    maximum,
                )
            }
            try await Task.sleep(
                for: .milliseconds(
                    50,
                ),
            )
            XCTAssertTrue(
                saved.isEmpty,
            )
            model.onFocusChanged(
                .name,
            )
            model.onTapToolbarDown()
            XCTAssertEqual(
                model.focus,
                .content,
            )
            model.onTapToolbarUp()
            XCTAssertEqual(
                model.focus,
                .name,
            )
            model.onSubmit()
            XCTAssertEqual(
                model.focus,
                .content,
            )
            model.onSubmit()
            XCTAssertNil(
                model.focus,
            )
            model.nameTextController.restoreText(
                "Boundary template",
            )
            let content = String(
                repeating: "я",
                count: container.applicationConfig.templateAdd.contentMaxLength,
            )
            model.templateTextController.restoreText(
                content,
            )
            model.usExaminationType = container.usExaminationTypesById[
                "bladder",
            ]!
            model.onTapSave()
            model.onTapSave()
            for _ in 0 ..< 100 {
                if !saved.isEmpty {
                    break
                }
                try await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTAssertEqual(
                saved.count,
                1,
                "Repeated save cannot create duplicate templates",
            )
            XCTAssertEqual(
                saved.first?.content,
                content,
            )
            XCTAssertEqual(
                saved.first?.name,
                "Boundary template",
            )
            XCTAssertEqual(
                saved.first?.usExaminationType.id,
                "bladder",
            )
        }

        func testTemplateEditBoundariesAndFocusKeepTheExistingIdentity() async throws {
            let container = DependencyContainer.previewable
            var saved: [USExaminationTemplate] = []
            let identity = UUID()
            let model = TemplateEditViewModel(
                container: container,
                router: router(
                    .templateEdit,
                ),
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                messager: DMessager(),
                arguments: TemplateEditArguments(
                    templateId: identity,
                ),
                onSaveTemplate: {
                    saved.append(
                        $0,
                    )
                },
                onDeleteTemplate: { _ in
                    XCTFail(
                        "Editing must not delete the template",
                    )
                },
            )
            model.preparePreview(
                state: TemplateEditDefaultState(),
            )
            let limits: [(DTextFieldController, Int, TemplateEditFocus)] = [
                (model.nameTextController, container.applicationConfig.templateEdit.nameMaxLength, .name),
                (model.templateTextController, container.applicationConfig.templateEdit.contentMaxLength, .content),
            ]
            for (field, maximum, focus) in limits {
                model.nameTextController.restoreText(
                    "Name",
                )
                model.templateTextController.restoreText(
                    "Content",
                )
                for value in ["", String(
                    repeating: "я",
                    count: maximum + 1,
                )] {
                    field.restoreText(
                        value,
                    )
                    model.onTapSave()
                    XCTAssertEqual(
                        model.focus,
                        focus,
                    )
                    XCTAssertTrue(
                        model.state is TemplateEditDefaultState,
                    )
                }
                for length in [maximum - 1, maximum] {
                    field.restoreText(
                        String(
                            repeating: "я",
                            count: length,
                        ),
                    )
                    XCTAssertTrue(
                        field.validate(),
                    )
                }
                field.clear()
                field.setText(
                    String(
                        repeating: "я",
                        count: maximum + 1,
                    ),
                )
                XCTAssertEqual(
                    field.text.count,
                    maximum,
                )
            }
            try await Task.sleep(
                for: .milliseconds(
                    50,
                ),
            )
            XCTAssertTrue(
                saved.isEmpty,
            )
            model.onFocusChanged(
                .name,
            )
            model.onTapToolbarDown()
            XCTAssertEqual(
                model.focus,
                .content,
            )
            model.onTapToolbarUp()
            XCTAssertEqual(
                model.focus,
                .name,
            )
            model.onSubmit()
            XCTAssertEqual(
                model.focus,
                .content,
            )
            model.onSubmit()
            XCTAssertNil(
                model.focus,
            )
            model.nameTextController.restoreText(
                "Boundary template",
            )
            let content = String(
                repeating: "я",
                count: container.applicationConfig.templateEdit.contentMaxLength,
            )
            model.templateTextController.restoreText(
                content,
            )
            model.usExaminationType = container.usExaminationTypesById[
                "bladder",
            ]!
            model.onTapSave()
            model.onTapSave()
            for _ in 0 ..< 100 {
                if !saved.isEmpty {
                    break
                }
                try await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTAssertEqual(
                saved.count,
                1,
                "Repeated save cannot create duplicate templates",
            )
            XCTAssertEqual(
                saved.first?.content,
                content,
            )
            XCTAssertEqual(
                saved.first?.name,
                "Boundary template",
            )
            XCTAssertEqual(
                saved.first?.id,
                identity,
            )
            XCTAssertEqual(
                saved.first?.usExaminationType.id,
                "bladder",
            )
        }

        func testSettingsAIEmptyFieldsAndKeyboardPreserveOptionalValues() async throws {
            let status = CurrentValueSubject<SubscriptionStatus?, Never>(
                ModulePreviewFactory.subscription,
            )
            var saved: [(Bool, Double?, Int?)] = []
            let model = settings(
                status: status,
            ) {
                saved.append(
                    ($2, $3, $4),
                )
            }
            model.onAppear()
            model.onFocusChanged(
                .temperature,
            )
            model.onTapToolbarDown()
            XCTAssertEqual(
                model.focus,
                .length,
            )
            model.onTapToolbarUp()
            XCTAssertEqual(
                model.focus,
                .temperature,
            )
            model.onSubmit()
            XCTAssertEqual(
                model.focus,
                .length,
            )
            model.onSubmit()
            XCTAssertNil(
                model.focus,
            )
            model.temperatureTextController.setText(
                "1a,5",
            )
            XCTAssertEqual(
                model.temperatureTextController.text,
                "1.5",
            )
            model.maxTokensTextController.setText(
                "10a24",
            )
            XCTAssertEqual(
                model.maxTokensTextController.text,
                "1024",
            )
            model.temperatureTextController.clear()
            model.maxTokensTextController.clear()
            model.onTapSave()
            for _ in 0 ..< 100 {
                if !saved.isEmpty {
                    break
                }
                try await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTAssertEqual(
                saved.count,
                1,
            )
            XCTAssertNil(
                saved.first?.1,
            )
            XCTAssertNil(
                saved.first?.2,
            )
            model.onDisappear()
        }

        func testSettingsAISubscriptionDowngradeDoesNotSaveRestrictedEdits() async throws {
            let status = CurrentValueSubject<SubscriptionStatus?, Never>(
                ModulePreviewFactory.subscription,
            )
            var saved: [(Bool, Double?, Int?)] = []
            let model = settings(
                status: status,
            ) {
                saved.append(
                    ($2, $3, $4),
                )
            }
            model.onAppear()
            XCTAssertTrue(
                model.isReportGenerationSettingsEnabled,
            )
            model.onFocusChanged(
                .temperature,
            )
            model.temperatureTextController.setText(
                "1.7",
            )
            model.maxTokensTextController.setText(
                "17",
            )
            model.toggleIsMarkdown()
            status.send(
                SubscriptionStatus(
                    planId: "base_weekly",
                    type: .base,
                    entitlement: .init(
                        requestCountPerDay: 10,
                        formCompletionViaMicrophone: .offered,
                        sendingReportByEmail: .offered,
                        settingsAI: .offered,
                    ),
                    availableCountPerDay: 10,
                ),
            )
            XCTAssertFalse(
                model.isReportGenerationSettingsEnabled,
            )
            XCTAssertNil(
                model.focus,
            )
            model.onTapSave()
            for _ in 0 ..< 100 {
                if !saved.isEmpty {
                    break
                }
                try await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTAssertEqual(
                saved.count,
                1,
            )
            XCTAssertEqual(
                saved.first?.0,
                false,
            )
            XCTAssertEqual(
                saved.first?.1,
                0.7,
            )
            XCTAssertEqual(
                saved.first?.2,
                1024,
            )
            status.send(
                ModulePreviewFactory.subscription,
            )
            XCTAssertTrue(
                model.isReportGenerationSettingsEnabled,
            )
            model.onDisappear()
        }

        func testDateSelectionKeepsChangesUnconfirmedAndAllowsLeapDay() {
            let container = DependencyContainer.previewable
            let calendar = Calendar.current
            let initial = calendar.date(
                from: DateComponents(
                    year: 1985,
                    month: 1,
                    day: 15,
                ),
            )!
            let leapDay = calendar.date(
                from: DateComponents(
                    year: 2000,
                    month: 2,
                    day: 29,
                ),
            )!
            var selected: [Date] = []
            let model = SelectDateOfBirthViewModel(
                container: container,
                router: router(),
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: SelectDateOfBirthArguments(
                    currentValue: initial,
                    onSelected: {
                        selected.append(
                            $0,
                        )
                    },
                ),
            )
            XCTAssertEqual(
                model.date,
                initial,
            )
            XCTAssertLessThanOrEqual(
                abs(
                    model.toDate.timeIntervalSinceNow,
                ),
                1,
            )
            XCTAssertEqual(
                calendar.date(
                    byAdding: .year,
                    value: 100,
                    to: model.fromDate,
                )!.timeIntervalSince1970,
                model.toDate.timeIntervalSince1970,
                accuracy: 0.001,
            )
            XCTAssertTrue(
                (model.fromDate ... model.toDate).contains(
                    leapDay,
                ),
            )
            model.onDateChanged(
                leapDay,
            )
            XCTAssertTrue(
                selected.isEmpty,
                "Scrolling the picker must not commit a birth date",
            )
            model.onTapSelect()
            XCTAssertEqual(
                selected,
                [leapDay],
            )
        }

        private func settings(
            status: CurrentValueSubject<SubscriptionStatus?, Never>,
            save: @escaping (TranscriberType, TranscriptParserType, Bool, Double?, Int?) async throws -> Void,
        ) -> SettingsAIViewModel {
            let container = DependencyContainer.previewable
            let model = SettingsAIViewModel(
                container: container,
                getInitialNeuralModel: {
                    container.usExaminationNeuralModelDefault
                },
                getInitialIsMarkdown: {
                    false
                },
                getInitialTemperature: {
                    0.7
                },
                getInitialMaxTokens: {
                    1024
                },
                messager: DMessager(),
                router: router(),
                getSubscriptionStatus: {
                    status.value
                },
                observeSubscriptionStatus: { observer in
                    status.sink(
                        receiveValue: observer,
                    )
                },
                onSubscriptionStatusUpdated: {
                    status.send(
                        $0,
                    )
                },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                onNeuralModelSelected: { _ in },
                onSettingsSaved: save,
            )
            model.transcriptParserType = .server
            return model
        }

        private func router(
            _ screen: ScreenType = .settingsAI,
        ) -> DRouter {
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: screen,
                ),
            )
            return router
        }
    }
#endif
