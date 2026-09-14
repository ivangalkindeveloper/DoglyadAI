import Foundation

@MainActor
final class SelectDateOfBirthViewModel: DViewModel {
    @Published var date: Date

    let fromDate: Date
    let toDate: Date

    private let arguments: SelectDateOfBirthArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SelectDateOfBirthArguments?
    ) {
        self.arguments = arguments
        toDate = Date()
        date = arguments?.currentValue ?? toDate
        fromDate = Calendar.current.date(
            byAdding: .year,
            value: -100,
            to: toDate
        )!
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.selectDateOfBirth),
            analyticsParameters: AnalyticsParameters([
                .hasCurrentValue: .bool(arguments?.currentValue != nil),
            ])
        )
    }

    func onTapSelect() {
        analytics.buttonTapped(.selectDateOfBirth)
        coordinator.dismissSheet()
        arguments?.onSelected(date)
    }
}
