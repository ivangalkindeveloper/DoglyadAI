import Combine
import DoglyadUI
import Foundation

@MainActor
final class SelectUSExaminationTypeViewModel: DModuleViewModel {
    private let messager: DMessager?
    struct Item: Identifiable {
        let id: String
        let type: USExaminationType
    }

    struct Section: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let items: [Item]

        init(
            id: String,
            title: LocalizedStringResource,
            types: [USExaminationType],
        ) {
            self.id = id
            self.title = title
            items = types.map { type in
                Item(
                    id: "\(id):\(type.id)",
                    type: type,
                )
            }
        }
    }

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
        super.init(
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

    @Published private(set) var recentTypeIds: [String] = []

    override func onInit() {
        handle { try await self.container.ultrasoundReportRepository.getRecentExaminationTypeIds() }
            onMainSuccess: { ids in self.recentTypeIds = ids } onMainUnknownError: { _ in
                self.messager?.showUnknownError(
                    l10n: self.container.l10n,
                )
            }
    }

    var sections: [Section] {
        let recentTypes = recentTypeIds.compactMap { container.usExaminationTypesById[
            $0,
        ] }
        let recentSections: [Section] = if recentTypes.isEmpty {
            []
        } else {
            [
                Section(
                    id: "recent",
                    title: container.l10n[
                        .usExaminationTypeRecentGroupTitle,
                    ],
                    types: recentTypes,
                ),
            ]
        }

        let configuredSections = container.usExaminationTypeGroups.map { group in
            Section(
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
        arguments?.currentValue == type
    }

    func onTypeTap(
        _ type: USExaminationType,
    ) {
        analytics.buttonTapped(
            .selectUSExaminationType,
        )
        handle {
            try await self.container.ultrasoundReportRepository.recordRecentExaminationTypeId(
                type.id,
            )
            try await self.arguments?.onSelected(
                type,
            )
        } onMainSuccess: { _ in self.coordinator.dismissSheet() } onMainUnknownError: { _ in
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
