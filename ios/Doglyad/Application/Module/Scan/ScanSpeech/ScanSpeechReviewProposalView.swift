import DoglyadUI
import SwiftUI

struct ScanSpeechReviewProposalView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    let state: ScanSpeechReviewProposalState
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    var body: some View {
        ScrollView(
            showsIndicators: false,
        ) {
            VStack(
                alignment: .leading,
                spacing: size.s4,
            ) {
                if state.reviewProposals.isEmpty {
                    DText(
                        l10n[
                            .scanSpeechProposalNoFieldsDescription,
                        ],
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                    )
                    .padding(
                        .bottom,
                        size.s8,
                    )
                } else {
                    DText(
                        viewModel.proposalInstructions,
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                    )
                    .padding(
                        .bottom,
                        size.s8,
                    )

                    ForEach(
                        state.reviewProposals,
                    ) { field in
                        ScanSpeechProposalCardView(
                            state: state,
                            proposal: field,
                        )
                    }
                }
            }
            .padding(
                size.s16,
            )
            .padding(
                .top,
                toolbarHeight,
            )
            .padding(
                .bottom,
                bottomHeight,
            )
        }
    }
}

#if DEBUG
    #Preview(
        "Несколько полей",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .multipleFields,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Частичный результат",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .partialResult,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Длинный клинический текст",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .clinicalText,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Ничего не распознано",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .empty,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }
#endif
