"""Validate the exact native UI tests; an empty or skipped XCTest run cannot pass."""

from pathlib import Path
import json
import subprocess

REQUIRED_TESTS = [
    "PatientReadinessTests/readinessRespectsSpeechConfidence(isReliable:)",
    "PatientReadinessTests/readinessSurvivesReportAndDraftStorage(isPrepared:)",
    "PatientReadinessTests/voiceReadinessRequiresOneExplicitStatement(scenario:)",
    "PatientReadinessTests/generatedReadinessCannotInvertNegation()",
    "ScanDraftRestorationTests/restoredReadinessRemainsFalseUntilFormClear()",
    'StorageConfirmationTests/speechModelDeletionRequiresConfirmationAndCancellationKeepsTheModel()',
    'StorageConfirmationTests/speechModelConfirmationDismissesAndCallsBackOnlyOnce()',
    'PatientConsentPersistenceTests/consentSurvivesDatabaseAndRequestRoundTrips(isPatientConsent:)',
    'PatientConsentTests/preferenceDefaultsToTrueAndSurvivesRepositoryReload()',
    'PatientConsentTests/confirmationPersistsChoiceBeforeDismissalAndCallsBackOnce(isDoNotAskAgain:)',
    'PatientConsentTests/failedPreferenceSaveRetainsChoiceAndAllowsRetry()',
    'PatientConsentTests/dismissalRejectsLateConfirmation()',
    'PatientConsentTests/sharedPreferenceUpdatesOnlyAfterSuccessfulPersistence()',
    'PatientConsentTests/settingsCanDisableAndReenableThePersistedPrompt()',
    'ScanPatientConsentTests/generationChecksPreferenceAndContinuesOnlyAfterConfirmation(isNeedPatientConsent:)',
    'ScanPatientConsentTests/failedPreferenceReadPreservesFormAndDoesNotGenerate()',
    'ScanPatientConsentTests/leavingScanDiscardsLatePreferenceRead()',

    'LocalOperationTests/leavingBeforeLocalWriteStartsDoesNotSendIt()',
    'ScanDraftRestorationTests/backgroundSaveWaitsForAnInteractiveLocalClear()',
    'LocalFormOperationTests/closingTemplateEditorRejectsLateReadResults(isFailure:)',
    'LocalFormOperationTests/settingsSaveRetainsEditsMadeDuringTheWrite()',
    'ScanDraftRestorationTests/localClearKeepsNewEditsAndClearsUntouchedFieldsWithoutLoading()',

    "RepositoryOperationTests/failedSelectionKeepsSheetOpenAndRetryDismissesOnlyAfterSaving()",
    'LocalOperationTests/localWriteKeepsPresentationAndRejectsDuplicateActions()',
    'LocalOperationTests/cancelledLocalWriteIgnoresLateResultAndCannotReplaceNewOperation(isFailure:)',
    'LocalOperationTests/failureIsReportedWithoutInventingALoadingPresentation()',

    "SelectUSExaminationTypeTests/dismissedSelectionIgnoresLateResults(isFailure:)",
    "ScanDraftRestorationTests/selectedTypeReadFailureKeepsTheStoredDraftIntactUntilRetry()",
    "ScanDraftRestorationTests/backgroundSaveWaitsForRestorationAndPersistsEarlyInput()",
    "ScanDraftRestorationTests/submissionDuringReadInvalidatesRestorationBeforePreparingGeneration()",
    "ScanDraftRestorationTests/delayedDraftMergesOnlyUntouchedValuesAndPersistsEarlyEdits()",
    "ScanDraftRestorationTests/clearDuringReadRejectsALateDraft()",
    "ScanDraftRestorationTests/missingDraftKeepsEarlyEditsAndRestoresUntouchedDefaults()",
    "SelectUSExaminationTypeTests/optionalRecentWriteCompletesAfterTheSheetCloses()",
    "ContentDesignTests/unavailableHistoryCountKeepsSettingsNavigationWithoutAnError()",
    "SelectUSExaminationTypeTests/requiredSelectionFailurePreservesValueAndReportsError()",
    "SelectUSExaminationTypeTests/recentWriteFailureDoesNotFailTheRequiredSelection()",
    "ContentDesignTests/failedSpeechPreviewConstructionHasNoErrorMessageOrStartupSideEffects()",
    "ContentDesignTests/photoImportPreservesAvailableImagesAndReportsOnlyFailures(isSomeImagesUnavailable:)",
    "ContentDesignTests/templateInitializationRetryMergesLoadedDataWithoutReplacingEdits()",
    "ContentDesignTests/scanInitializationRetryPreservesEditsAndRestoresUntouchedDraftFields()",
    "ContentDesignTests/historyPaginationFailureRetainsItemsAndRetriesTheSameOffset()",
    "WebDocumentTests/retryIgnoresCallbacksFromThePreviousDocumentLoad()",
    "HistoryTests/historyClearRemovesOwnedAndLegacyOrphanRecordsButKeepsTemplates()",
    "ManageSubscriptionTests/catalogRetryLoadsTheSameActiveSubscription()",
    "ManageSubscriptionTests/leavingDiscardsLateManagementSuccessAndFailure(isFailure:)",
    "PaywallTests/loadingRetriesAndRestorationUpdatesSharedState(isSubscriptionActive:)",
    "PaywallTests/cancelledCatalogDiscardsLateSuccessAndFailure(isFailure:)",
    "PaywallTests/closeIgnoresALateCatalogResponse()",
    "RegressionFormTests/testRecoveryIgnoresLateResponseAfterLeavingAndRetainsFailedInput()",
    "SubscriptionRecoveryTests/generatedKeyIsRetainedWhenAnOperationFails()",
    "ManageSubscriptionTests/aCatalogFailureIsDistinctFromAnUnsubscribedOwner()",
    "ManageSubscriptionTests/failedManagementRetainsTheCurrentSubscriptionSnapshot()",
    "ManageSubscriptionTests/leavingBeforeManagementStartsDoesNotSendTheOperation()",
    "RegressionFormTests/testYooKassaRestorationOpensRecoveryWithoutStartingAppleOrPaymentOperations()",
    "PaywallTests/pendingPurchaseDoesNotCompleteFromUnrelatedBaseAccess()",
    "RegressionFormTests/testModelAvailabilityAndSubscriptionGateEverySelection()",
    "RegressionFormTests/testTemplateEditBoundariesAndFocusKeepTheExistingIdentity()",
    "RegressionFormTests/testParserAvailabilityRefreshesOnForegroundAndBlocksUnavailableSelection()",
    "RegressionFormTests/testTranscriberAvailabilityRefreshesOnForegroundWithoutDuplicates()",
    "PhotoLibraryRegressionTests/testUnavailableImageDoesNotDropOtherSelectedImagesOrChangeTheirOrder()",
    "PhotoLibraryRegressionTests/testExportSevenSimulatorCameraImagesForTheSystemPhotoPicker()",
    "PhotoViewGestureTests/testDoubleTapAndPinch()",
    "PhotoViewGestureTests/testPortraitDoubleTapAndPinch()",
    "PhotoViewGestureTests/testSquareDoubleTapAndPinch()",
    "ScanCameraRegressionTests/testCaptureRejectsDuplicatesLateCallbacksAndLimitOverflow()",
    "ModuleStateTests/photoViewerTracksSourceChangesAndDeletesThroughArguments()",
    "ModuleStateTests/photoRemarksFollowTheNewReportWhenPhotosHaveNotChanged()",
    "ScanSpeechRegressionTests/testRecordingRejectsDuplicateActionsAndLateTranscript()",
    "ScanSpeechRegressionTests/testEmptyAndOversizedTranscriptCannotStartParsing()",
    "RegressionFormTests/testScanRejectsInvalidRestoredFieldsAndPreservesFocusOrder()",
    "RegressionFormTests/testTemplateBoundariesRejectWritesAndKeepFullContent()",
    "RegressionFormTests/testSettingsAIEmptyFieldsAndKeyboardPreserveOptionalValues()",
    "RegressionFormTests/testSettingsAISubscriptionDowngradeDoesNotSaveRestrictedEdits()",
    "RegressionFormTests/testDateSelectionKeepsChangesUnconfirmedAndAllowsLeapDay()",
    "ModuleStateTests/dateSelectionPublishesChangesAndConfirmsLatestValue()",
    "ModuleStateTests/legalAcceptanceEmitsImmutableSnapshotsAndKeepsConsentGate()",
    "DSpeechWhisperKitModelTests/availabilityRequiresAllDownloadedModelComponents()",
    "DSpeechWhisperKitModelTests/deletionRemovesModelAndTokenizerButPreservesOtherData()",
    "DSpeechWhisperKitModelTests/failedDeletionPropagatesErrorAndKeepsModelAvailableForRetry()",
    "DSpeechWhisperKitModelTests/cancelledDeletionKeepsFilesAndStoredPath()",
    "StatePersistenceTests/failedHistoryUpdateRetainsResultAndRetriesWithoutNewGeneration()",
    "StatePersistenceTests/generationStartsOnlyAfterHistorySaveAndDoesNotDuplicateEntry()",
    "StatePersistenceTests/disconnectedStreamRecoversSameTaskAfterScreenObserverLeaves()",
    "StatePersistenceTests/backgroundSuspendsStreamWithoutInterruptionAndResumesSameTask(isImmediateReturn:)",
    "StatePersistenceTests/newProcessMarksPendingHistoryInterruptedWithoutNetwork()",
    "SettingsAITests/losingProRemovesFocusAndUpdatesControlAvailabilityWithoutLosingSpeechChoices()",
    "SettingsAITests/unavailableFoundationModelsCannotBeSelectedAndServerRemainsSelectable()",
    "DictationModelCompositionTests/capabilityChanges()",
    "DictationModelCompositionTests/cancellationAfterResponse()",
    "DictationModelCompositionTests/unavailableExplicitFoundationChoice()",
    "PhotoViewImageTransformTests/annotationCoordinatesFollowImageScaleAndOffset()",
    "PhotoViewImageTransformTests/zoomAroundAnnotationKeepsItAtTheTouchedPosition()",
    "PhotoViewImageTransformTests/centerZoomDoesNotDrift()",
    "PhotoViewImageTransformTests/offCenterZoomKeepsTheTouchedPixelInPlace()",
    "PhotoViewImageTransformTests/panningStopsAtImageEdges()",
    "PhotoViewImageTransformTests/minimumZoomReturnsToTheOriginalPosition()",
    "SettingsAITests/transcriberListOffersOnlyTheAvailableAppleEngineAndWhisperKit(appleTranscriber:)",
    "SettingsAITests/speechChoicesSurviveRepositoryReloadAndReportStorage(transcriber:parser:)",
    "SettingsAITests/reportSettingsRequireProWhileSpeechSettingsRemainEditable(type:availability:)",
]

# XCTest filters omit parentheses; Swift Testing filters retain the full signature.
XCTEST_SUITES = {
    "PhotoViewGestureTests",
    "ScanCameraRegressionTests",
    "ScanSpeechRegressionTests",
    "RegressionFormTests",
    "PhotoLibraryRegressionTests",
}
TEST_FILTERS = [
    (
        "DoglyadUITests/"
        if name.startswith("PhotoViewGestureTests/")
        else "DoglyadTests/"
    )
    + (name.removesuffix("()") if name.split("/")[0] in XCTEST_SUITES else name)
    for name in REQUIRED_TESTS
]

ARGUMENT_COUNTS = {
    "PatientReadinessTests/readinessRespectsSpeechConfidence(isReliable:)": 2,
    "PatientReadinessTests/readinessSurvivesReportAndDraftStorage(isPrepared:)": 2,
    "PatientReadinessTests/voiceReadinessRequiresOneExplicitStatement(scenario:)": 15,
    'PatientConsentPersistenceTests/consentSurvivesDatabaseAndRequestRoundTrips(isPatientConsent:)': 2,
    'PatientConsentTests/confirmationPersistsChoiceBeforeDismissalAndCallsBackOnce(isDoNotAskAgain:)': 2,
    'ScanPatientConsentTests/generationChecksPreferenceAndContinuesOnlyAfterConfirmation(isNeedPatientConsent:)': 2,
    'LocalFormOperationTests/closingTemplateEditorRejectsLateReadResults(isFailure:)': 2,
    'LocalOperationTests/cancelledLocalWriteIgnoresLateResultAndCannotReplaceNewOperation(isFailure:)': 2,
    "SelectUSExaminationTypeTests/dismissedSelectionIgnoresLateResults(isFailure:)": 2,
    "ContentDesignTests/photoImportPreservesAvailableImagesAndReportsOnlyFailures(isSomeImagesUnavailable:)": 2,
    "ManageSubscriptionTests/leavingDiscardsLateManagementSuccessAndFailure(isFailure:)": 2,
    "PaywallTests/loadingRetriesAndRestorationUpdatesSharedState(isSubscriptionActive:)": 2,
    "PaywallTests/cancelledCatalogDiscardsLateSuccessAndFailure(isFailure:)": 2,
    "StatePersistenceTests/backgroundSuspendsStreamWithoutInterruptionAndResumesSameTask(isImmediateReturn:)": 2,
    "SettingsAITests/transcriberListOffersOnlyTheAvailableAppleEngineAndWhisperKit(appleTranscriber:)": 3,
    "SettingsAITests/speechChoicesSurviveRepositoryReloadAndReportStorage(transcriber:parser:)": 6,
    "SettingsAITests/reportSettingsRequireProWhileSpeechSettingsRemainEditable(type:availability:)": 9,
}


def validate_results(summary: dict, tree: dict) -> dict:
    results = []

    def walk(nodes):
        for node in nodes:
            if node.get("nodeType") == "Test Case":
                arguments = [
                    child
                    for child in node.get("children", [])
                    if child.get("nodeType") == "Arguments"
                ]
                if len(arguments) != ARGUMENT_COUNTS.get(
                    node["nodeIdentifier"], 0
                ) or any(child.get("result") != "Passed" for child in arguments):
                    raise ValueError("Required native test variants did not all pass")
                results.append({"id": node["nodeIdentifier"], "result": node["result"]})
            walk(node.get("children", []))

    walk(tree.get("testNodes", []))
    if (
        summary.get("result") != "Passed"
        or summary.get("totalTestCount") != len(REQUIRED_TESTS)
        or summary.get("passedTests") != len(REQUIRED_TESTS)
        or summary.get("failedTests") != 0
        or summary.get("skippedTests") != 0
        or summary.get("expectedFailures", 0) != 0
        or sorted(item["id"] for item in results) != sorted(REQUIRED_TESTS)
        or any(item["result"] != "Passed" for item in results)
    ):
        raise ValueError("Required native UI tests did not all pass")
    by_id = {item["id"]: item for item in results}
    return {
        "requiredTests": REQUIRED_TESTS,
        "results": [by_id[name] for name in REQUIRED_TESTS],
    }


def collect(bundle: Path, destination: Path) -> None:
    def read(kind):
        return json.loads(
            subprocess.check_output(
                [
                    "xcrun",
                    "xcresulttool",
                    "get",
                    "test-results",
                    kind,
                    "--path",
                    str(bundle),
                    "--format",
                    "json",
                ],
                text=True,
            )
        )

    evidence = validate_results(read("summary"), read("tests"))
    destination.write_text(json.dumps(evidence, indent=2) + "\n")
