#if DEBUG
    import DoglyadUI
    import Router
    import SwiftUI

    struct ScanSpeechTranscriptPreviewView: DViewProtocol {
        @EnvironmentObject private var messager: DMessager
        @EnvironmentObject var theme: DTheme

        private let container: DependencyContainer
        private let router: DRouter
        private let fixture: ScanSpeechTranscriptPreviewFixture
        let scenario: ScanSpeechTranscriptPreviewFixture.Scenario

        init(
            scenario: ScanSpeechTranscriptPreviewFixture.Scenario,
        ) {
            container = ScanSpeechPreviewFactory.makeContainer()
            router = DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            )
            fixture = ScanSpeechTranscriptPreviewFixture(
                scenario: scenario,
            )
            self.scenario = scenario
        }

        var body: some View {
            let viewModel = fixture.makeViewModel(
                container: container,
                messager: messager,
                router: router,
            )

            ScanSpeechTranscriptPreviewContentView(
                viewModel: viewModel,
            )
            .id(
                scenario,
            )
            .localization(
                container.l10n,
            )
        }
    }

    private struct ScanSpeechTranscriptPreviewContentView: DViewProtocol {
        @EnvironmentObject private var l10n: L10N
        @EnvironmentObject var theme: DTheme
        @StateObject var viewModel: ScanSpeechViewModel
        @State private var isPresented = true

        var body: some View {
            DCardBackground(
                cornerRadius: .zero,
                color: color.grayscaleHeader,
            )
            .ignoresSafeArea()
            .sheet(
                isPresented: $isPresented,
            ) {
                DBottomSheet(
                    type: .blur,
                    title: l10n[
                        .scanSpeechTitle,
                    ],
                    fraction: 0.9,
                ) { toolbarHeight, bottomHeight in
                    ScanSpeechReviewTranscriptView(
                        toolbarHeight: toolbarHeight,
                        bottomHeight: bottomHeight,
                    )
                } bottom: {
                    ScanSpeechReviewTranscriptBottomView()
                        .allowsHitTesting(
                            false,
                        )
                }
            }
            .environmentObject(
                viewModel,
            )
        }
    }
#endif
