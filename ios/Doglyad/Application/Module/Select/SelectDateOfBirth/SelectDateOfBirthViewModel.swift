import Combine
import Foundation

@MainActor
final class SelectDateOfBirthViewModel: DModuleViewModel {
    @Published var date: Date

    let fromDate: Date
    let toDate: Date

    private let arguments: SelectDateOfBirthArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SelectDateOfBirthArguments?,
    ) {
        self.arguments = arguments
        toDate = Date()
        date = arguments?.currentValue ?? toDate
        fromDate = Calendar.current.date(
            byAdding: .year,
            value: -100,
            to: toDate,
        )!
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
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
