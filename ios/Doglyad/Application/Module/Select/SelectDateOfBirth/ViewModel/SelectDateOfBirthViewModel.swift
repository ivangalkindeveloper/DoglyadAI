import Combine
import Foundation

@MainActor
final class SelectDateOfBirthViewModel: DModuleViewModel<any SelectDateOfBirthStateProtocol> {
    @Published private(set) var date: Date
    let fromDate: Date
    let toDate: Date

    private let arguments: SelectDateOfBirthArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SelectDateOfBirthArguments?,
    ) {
        self.arguments = arguments
        let toDate = Date()
        self.toDate = toDate
        date = arguments?.currentValue ?? toDate
        fromDate = Calendar.current.date(
            byAdding: .year,
            value: -100,
            to: toDate,
        )!
        super.init(
            state: SelectDateOfBirthState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .selectDateOfBirth,
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

    func onDateChanged(
        _ newDate: Date,
    ) {
        date = newDate
    }

    func onTapSelect() {
        analytics.buttonTapped(
            .selectDateOfBirth,
        )
        coordinator.dismissSheet()
        arguments?.onSelected(
            date,
        )
    }
}
