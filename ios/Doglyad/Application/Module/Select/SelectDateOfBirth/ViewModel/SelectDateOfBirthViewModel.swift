import Combine
import Foundation

@MainActor
final class SelectDateOfBirthViewModel: DModuleViewModel<any SelectDateOfBirthStateProtocol> {
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
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: SelectDateOfBirthArguments?,
    ) {
        let toDate = Date()
        fromDate = Calendar.current.date(
            byAdding: .year,
            value: -100,
            to: toDate,
        )!
        self.toDate = toDate
        self.arguments = arguments
        super.init(
            state: SelectDateOfBirthDefaultState(
                date: arguments?.currentValue ?? toDate,
            ),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
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
        emit(
            state.copyWith(
                date: newDate,
            ),
        )
    }

    func onTapSelect() {
        analytics.buttonTapped(
            .selectDateOfBirth,
        )
        coordinator.dismissSheet()
        arguments?.onSelected(
            state.date,
        )
    }
}
