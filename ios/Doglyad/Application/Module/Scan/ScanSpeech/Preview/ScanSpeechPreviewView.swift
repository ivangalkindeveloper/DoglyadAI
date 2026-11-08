#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct ScanSpeechPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any ScanSpeechStateProtocol

        var body: some View {
            let model = ScanSpeechTranscriptPreviewFixture(
                scenario: .finished,
            ).makeViewModel(
                container: container,
                messager: messager,
                router: router,
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                ScanSpeechBottomSheetView(
                    viewModel: model,
                )
            }
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }

    struct ScanSpeechProposalPreviewLayoutView: DViewProtocol {
        @EnvironmentObject var theme: DTheme
        @EnvironmentObject private var l10n: L10N
        let state: ScanSpeechReviewProposalState
        let layout: ScanSpeechProposalPreviewLayout
        @Binding var isPresented: Bool

        var body: some View {
            switch layout {
            case .review:
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
                        accessibilityElement: .contain,
                        accessibilityIdentifier: "regression.\(UserDefaults.standard.string(forKey: "regressionPreview") ?? "unknown")",
                    ) { toolbarHeight, bottomHeight in
                        ScanSpeechReviewProposalView(
                            state: state,
                            toolbarHeight: toolbarHeight,
                            bottomHeight: bottomHeight,
                        )
                    } bottom: {
                        ScanSpeechReviewProposalBottomView(
                            state: state,
                        )
                        .allowsHitTesting(
                            false,
                        )
                    }
                }
            case .card:
                if let proposal = state.reviewProposals.first {
                    ScanSpeechProposalCardView(
                        state: state,
                        proposal: proposal,
                    )
                    .padding(
                        size.s16,
                    )
                    .frame(
                        width: 390,
                    )
                    .background {
                        DCardBackground(
                            cornerRadius: .zero,
                            color: color.grayscaleInput,
                        )
                    }
                }
            }
        }
    }

    enum ScanSpeechProposalPreviewLayout: Hashable {
        case review
        case card
    }

    private struct ScanSpeechProposalPreviewID: Hashable {
        let scenario: ScanSpeechProposalPreviewFixture.Scenario
        let layout: ScanSpeechProposalPreviewLayout
        let isSelected: Bool
    }

    struct ScanSpeechProposalPreviewView: DViewProtocol {
        @EnvironmentObject private var messager: DMessager
        @EnvironmentObject var theme: DTheme

        private let container: DependencyContainer
        private let router: DRouter
        private let fixture: ScanSpeechProposalPreviewFixture
        private let identity: ScanSpeechProposalPreviewID
        let layout: ScanSpeechProposalPreviewLayout

        init(
            scenario: ScanSpeechProposalPreviewFixture.Scenario,
            layout: ScanSpeechProposalPreviewLayout,
            isSelected: Bool = false,
        ) {
            container = ScanSpeechPreviewFactory.makeContainer()
            router = DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            )
            fixture = ScanSpeechProposalPreviewFixture(
                scenario: scenario,
                isSelected: isSelected,
            )
            identity = ScanSpeechProposalPreviewID(
                scenario: scenario,
                layout: layout,
                isSelected: isSelected,
            )
            self.layout = layout
        }

        var body: some View {
            let viewModel = fixture.makeViewModel(
                container: container,
                messager: messager,
                router: router,
            )

            ScanSpeechProposalPreviewContentView(
                viewModel: viewModel,
                layout: layout,
            )
            // Canvas may reuse named previews; reset their model and sheet together.
            .id(
                identity,
            )
            .localization(
                container.l10n,
            )
        }
    }

    private struct ScanSpeechProposalPreviewContentView: DViewProtocol {
        @EnvironmentObject private var l10n: L10N
        @EnvironmentObject var theme: DTheme
        @StateObject var viewModel: ScanSpeechViewModel
        @State private var isPresented = true
        let layout: ScanSpeechProposalPreviewLayout

        var body: some View {
            Group {
                switch viewModel.state {
                case let state as ScanSpeechReviewProposalState:
                    ScanSpeechProposalPreviewLayoutView(
                        state: state,
                        layout: layout,
                        isPresented: $isPresented,
                    )
                default:
                    EmptyView()
                }
            }
            // Review snapshots are seeded directly; module initialization would prepare ASR.
            .environmentObject(
                viewModel,
            )
        }
    }

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
        @FocusState private var transcriptFocus: Bool?
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
                    accessibilityElement: .contain,
                    accessibilityIdentifier: "regression.\(UserDefaults.standard.string(forKey: "regressionPreview") ?? "unknown")",
                ) { toolbarHeight, bottomHeight in
                    ScanSpeechReviewTranscriptView(
                        transcriptFocus: $transcriptFocus,
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
