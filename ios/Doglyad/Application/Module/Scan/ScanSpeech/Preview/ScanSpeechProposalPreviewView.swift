#if DEBUG
    import DoglyadUI
    import Router
    import SwiftUI

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
#endif
