#if DEBUG
    import DoglyadUI
    import Router
    import SwiftUI

    struct HistoryPreviewView: View {
        let scenario: HistoryPreviewFactory.Scenario
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter

        var body: some View {
            let isErrorPresented = switch scenario {
            case .failed, .nextPageFailed: true
            default: false
            }

            HistoryScreenView(
                viewModel: HistoryPreviewFactory.makeViewModel(
                    scenario: scenario,
                    container: container,
                    router: router,
                ),
            )
            .previewError(
                isPresented: isErrorPresented,
            )
            .id(
                scenario,
            )
        }
    }
#endif
