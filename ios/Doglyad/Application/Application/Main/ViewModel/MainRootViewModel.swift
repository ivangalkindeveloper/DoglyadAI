import SwiftUI

@MainActor
final class MainRootViewModel: DStateViewModel<any MainRootStateProtocol> {
    private let container: DependencyContainer

    private var isReviewRequestChecked = false

    init(
        container: DependencyContainer,
    ) {
        self.container = container
        super.init(
            state: MainRootState(),
        )
    }

    func onAppear(
        requestReview: @escaping @MainActor () -> Void,
    ) {
        guard !isReviewRequestChecked else { return }
        isReviewRequestChecked = true

        Task {
            await requestReviewIfEligible(
                requestReview: requestReview,
            )
        }
    }

    private func requestReviewIfEligible(
        requestReview: @MainActor () -> Void,
    ) async {
        do {
            let reportsCount = try await container.ultrasoundReportRepository.getReportsCount()
            guard !Task.isCancelled, reportsCount > 0 else { return }
            try await Task.sleep(
                for: .seconds(
                    2,
                ),
            )
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        requestReview()
    }
}
