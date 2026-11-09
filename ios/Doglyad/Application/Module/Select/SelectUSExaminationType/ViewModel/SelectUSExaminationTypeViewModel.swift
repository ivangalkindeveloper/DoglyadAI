import Combine
import DoglyadUI
import Foundation

@MainActor
final class SelectUSExaminationTypeViewModel: DModuleViewModel<any SelectUSExaminationTypeStateProtocol> {
    @Published var recentTypeIds: [String] = []
    private let typesById: [String: USExaminationType]
    private let groups: [USExaminationTypeGroup]
    @Published var currentValue: USExaminationType?
    private let messager: DMessager?
    private let arguments: SelectUSExaminationTypeArguments?
    private var selectionOperation: UUID?
    private(set) var recentTypesReadTask: Task<Void, Never>?
    private(set) var recentTypeRecordTask: Task<Void, Never>?

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: SelectUSExaminationTypeArguments?,
    ) {
        typesById = container.usExaminationTypesById
        groups = container.usExaminationTypeGroups

        currentValue = (arguments?.currentValue)
        self.messager = messager
        self.arguments = arguments

        super.init(
            state: SelectUSExaminationTypeContentState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .selectUSExaminationType,
            ),
            analyticsParameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        arguments?.currentValue != nil,
                    ),
                ],
            ),
        )
    }

    var sections: [SelectUSExaminationTypeSection] {
        let recentTypes = recentTypeIds.compactMap {
            typesById[
                $0,
            ]
        }
        let recentSections: [SelectUSExaminationTypeSection] = if recentTypes.isEmpty {
            []
        } else {
            [
                SelectUSExaminationTypeSection(
                    id: "recent",
                    title: l10n[
                        .usExaminationTypeRecentGroupTitle,
                    ],
                    types: recentTypes,
                ),
            ]
        }

        let configuredSections = groups.map { group in
            SelectUSExaminationTypeSection(
                id: group.id,
                title: group.localizedTitle,
                types: group.examinationTypes,
            )
        }
        return recentSections + configuredSections
    }

    func isSelected(
        _ type: USExaminationType,
    ) -> Bool {
        currentValue == type
    }

    override func onInit() {
        recentTypesReadTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let ids = try await container.ultrasoundReportRepository.getRecentExaminationTypeIds()
                guard !Task.isCancelled else {
                    return
                }
                recentTypeIds = ids
            } catch {
                // Recent types are optional; the configured catalog stays available.
            }
        }
    }

    override func onDisappear() {
        super.onDisappear()
        lastTask?.cancel()
        selectionOperation = nil
        recentTypesReadTask?.cancel()
        recentTypesReadTask = nil
    }

    func onTypeTap(
        _ type: USExaminationType,
    ) {
        analytics.buttonTapped(
            .selectUSExaminationType,
        )
        guard selectionOperation == nil else {
            return
        }
        let operation = UUID()
        selectionOperation = operation
        handle {
            try await self.arguments?.onSelected(
                type,
            )
            try Task.checkCancellation()
        } onMainSuccess: { _ in
            guard !Task.isCancelled, self.selectionOperation == operation else {
                return
            }
            self.recentTypesReadTask?.cancel()
            // The optional write may finish after the sheet closes; reads are presentation-scoped.
            self.recentTypeRecordTask = Task { [weak self] in
                guard let self else {
                    return
                }
                do {
                    try Task.checkCancellation()
                    try await container.ultrasoundReportRepository.recordRecentExaminationTypeId(
                        type.id,
                    )
                } catch {
                    // Optional metadata does not change the result of the required selection.
                }
            }
            self.currentValue = type
            self.selectionOperation = nil
            self.coordinator.dismissSheet()
        } onMainUnknownError: { _ in
            guard !Task.isCancelled, self.selectionOperation == operation else {
                return
            }
            self.selectionOperation = nil
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
