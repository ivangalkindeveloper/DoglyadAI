import SwiftUI

@MainActor
final class MainRootViewModel: ObservableObject {
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
    }

    private var hasCheckedReviewRequest = false

    func onAppear(
        requestReview: @escaping @MainActor () -> Void
    ) {
        guard !hasCheckedReviewRequest else { return }
        hasCheckedReviewRequest = true

        Task {
            await requestReviewIfEligible(requestReview: requestReview)
        }
    }

    private func requestReviewIfEligible(
        requestReview: @MainActor () -> Void
    ) async {
        let reportsCount = await container.ultrasoundReportRepository.getReportsCount()
        guard !Task.isCancelled, reportsCount > 0 else { return }

        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        requestReview()
    }
}
