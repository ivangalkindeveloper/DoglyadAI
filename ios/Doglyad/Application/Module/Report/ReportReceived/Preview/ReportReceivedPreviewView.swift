#if DEBUG
    import DoglyadUI
    import Router
    import SwiftUI

    struct ReportReceivedPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var messager: DMessager
        @EnvironmentObject private var router: DRouter
        let scenario: ReportReceivedPreviewFactory.Scenario

        init(
            scenario: ReportReceivedPreviewFactory.Scenario,
        ) {
            self.scenario = scenario
        }

        var body: some View {
            ModuleBottomSheetPreviewView {
                ReportReceivedBottomSheetView(
                    viewModel: ReportReceivedPreviewFactory.makeViewModel(
                        scenario: scenario,
                        container: container,
                        messager: messager,
                        router: router,
                    ),
                )
            }
            .id(
                scenario,
            )
            .background(
                .black,
            )
            .previewError(
                isPresented: scenario == .deliveryFailed,
            )
        }
    }
#endif
