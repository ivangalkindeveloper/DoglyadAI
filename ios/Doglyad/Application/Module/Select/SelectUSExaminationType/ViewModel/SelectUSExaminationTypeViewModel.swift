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

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SelectUSExaminationTypeArguments?,
    ) {
        self.messager = messager
        self.arguments = arguments

        typesById = container.usExaminationTypesById
        groups = container.usExaminationTypeGroups

        currentValue = (arguments?.currentValue)

        super.init(
            state: SelectUSExaminationTypeLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
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
        let recentTypes = recentTypeIds.compactMap { typesById[
            $0,
        ] }
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
        let loading = SelectUSExaminationTypeLoadingState()
        emit(
            loading,
        )
        handle { try await self.container.ultrasoundReportRepository.getRecentExaminationTypeIds() }
            onMainSuccess: { ids in
                guard ObjectIdentifier(
                    self.state,
                ) == ObjectIdentifier(
                    loading,
                ) else { return }
                self.recentTypeIds = ids
                self.emit(
                    SelectUSExaminationTypeContentState(),
                )
            } onMainUnknownError: { error in
                guard ObjectIdentifier(
                    self.state,
                ) == ObjectIdentifier(
                    loading,
                ) else { return }
                self.emit(
                    SelectUSExaminationTypeFailedState(
                        error: error,
                    ),
                )
                self.messager?.showUnknownError(
                    l10n: self.container.l10n,
                )
            }
    }

    func onTapRetry() { onInit() }

    func onTypeTap(
        _ type: USExaminationType,
    ) {
        analytics.buttonTapped(
            .selectUSExaminationType,
        )
        switch state {
        case _ as SelectUSExaminationTypeSelectingState: return
        default: break
        }

        emit(
            SelectUSExaminationTypeSelectingState(),
        )
        handle {
            try await self.container.ultrasoundReportRepository.recordRecentExaminationTypeId(
                type.id,
            )
            try await self.arguments?.onSelected(
                type,
            )
        } onMainSuccess: { _ in
            self.currentValue = type
            self.emit(
                SelectUSExaminationTypeContentState(),
            )
            self.coordinator.dismissSheet()
        } onMainUnknownError: { _ in
            self.emit(
                SelectUSExaminationTypeContentState(),
            )
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
