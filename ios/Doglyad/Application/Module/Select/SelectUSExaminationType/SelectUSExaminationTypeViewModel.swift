import Foundation

@MainActor
final class SelectUSExaminationTypeViewModel: DViewModel {
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
            types: [USExaminationType]
        ) {
            self.id = id
            self.title = title
            items = types.map { type in
                Item(
                    id: "\(id):\(type.id)",
                    type: type
                )
            }
        }
    }

    private let arguments: SelectUSExaminationTypeArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SelectUSExaminationTypeArguments?
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.selectUSExaminationType),
            analyticsParameters: AnalyticsParameters([
                .hasCurrentValue: .bool(arguments?.currentValue != nil),
            ])
        )
    }

    var sections: [Section] {
        let recentTypes = container.ultrasoundReportRepository
            .getRecentExaminationTypeIds()
            .compactMap { container.usExaminationTypesById[$0] }
        let recentSections: [Section]
        if recentTypes.isEmpty {
            recentSections = []
        } else {
            recentSections = [
                Section(
                    id: "recent",
                    title: .usExaminationTypeRecentGroupTitle,
                    types: recentTypes
                ),
            ]
        }

        let configuredSections = container.usExaminationTypeGroups.map { group in
            Section(
                id: group.id,
                title: group.getLocalizedTitle(for: Locale.current),
                types: group.examinationTypes
            )
        }
        return recentSections + configuredSections
    }

    func isSelected(_ type: USExaminationType) -> Bool {
        arguments?.currentValue == type
    }

    func onTypeTap(_ type: USExaminationType) {
        analytics.buttonTapped(.selectUSExaminationType)
        container.ultrasoundReportRepository.recordRecentExaminationTypeId(type.id)
        coordinator.dismissSheet()
        arguments?.onSelected(type)
    }
}
