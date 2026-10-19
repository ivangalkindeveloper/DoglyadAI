import Combine
@testable import Doglyad
import Foundation
import Router
import Testing

@MainActor
struct RepositoryOperationTests {
    @Test
    func failedSelectionKeepsSheetOpenAndRetryDismissesOnlyAfterSaving() async {
        let container = DependencyContainer.previewable
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        let template = USExaminationTemplate(
            usExaminationType: container.usExaminationTypeDefault,
            name: "Template",
            content: "Content",
        )
        var isStorageAvailable = false
        var selectedTemplate: USExaminationTemplate?
        let arguments = SelectTemplateArguments(
            onSelected: { value in
                await Task.yield()
                guard isStorageAvailable else { throw CocoaError(
                    .fileWriteUnknown,
                ) }
                selectedTemplate = value
            },
        )
        let model = SelectTemplateViewModel(
            container: container,
            router: router,
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: { container.initialSettingsAI },
            onRequestCountIncremented: {},
            arguments: arguments,
        )
        model.emit(
            SelectTemplateContentState(),
        )
        model.coordinator.sheet(
            .selectTemplate,
            arguments: arguments,
        )
        model.onTemplateTap(
            template,
        )
        await model.lastTask?.value
        #expect(
            selectedTemplate == nil,
        )
        #expect(
            router.sheet != nil,
        )

        isStorageAvailable = true
        model.onTemplateTap(
            template,
        )
        #expect(
            router.sheet != nil,
        )
        await model.lastTask?.value
        #expect(
            selectedTemplate == template,
        )
        #expect(
            router.sheet == nil,
        )
    }
}
