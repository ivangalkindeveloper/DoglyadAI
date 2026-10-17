import DoglyadUI
import SwiftUI

struct ScanSpeechReviewView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as ScanSpeechPreparingRecordingState, _ as ScanSpeechPreparingModelState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechTranscribingState, _ as ScanSpeechAutomaticParsingState: true
        default: false
        }
        switch viewModel.state {
        case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechAutomaticParsingState, _ as ScanSpeechProposalReviewState:
            VStack(
                spacing: size.s16,
            ) {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: size.s16,
                    ) {
                        DText(
                            viewModel.transcriptStatusDescription,
                        ).dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleHeader,
                        )
                        DTextField(
                            controller: viewModel.transcriptController,
                            title: l10n[
                                .scanSpeechReviewFieldTitle,
                            ],
                            placeholder: l10n[
                                .scanSpeechReviewFieldPlaceholder,
                            ],
                            mode: DTextFieldMultiLineMode(
                                lineLimit: 6 ... 14,
                            ),
                        )
                        .disabled(
                            isProcessing,
                        )
                    }
                }.scrollDismissesKeyboard(
                    .interactively,
                )
                DButton(
                    title: l10n[
                        .scanSpeechReviewContinueButton,
                    ],
                    action: viewModel.onTapContinue,
                    isLoading: isProcessing,
                    isDisabled: isProcessing || viewModel.textForParsing == nil,
                ).dStyle(
                    .primaryButton,
                )
                DButton(
                    title: l10n[
                        .scanSpeechReviewRecordAgainButton,
                    ],
                    action: viewModel.onTapRecordAgain,
                    isDisabled: isProcessing,
                ).dStyle(
                    .primaryText,
                )
            }.padding(
                size.s16,
            )
        default: DUnexpectedStateView(
                state: viewModel.state,
            )
        }
    }
}
