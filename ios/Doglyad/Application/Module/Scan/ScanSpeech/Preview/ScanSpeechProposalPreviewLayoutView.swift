#if DEBUG
    import DoglyadUI
    import SwiftUI

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
#endif
