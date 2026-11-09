import DoglyadUI
import SwiftUI

struct ScanSpeechReviewTranscriptView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    let transcriptFocus: FocusState<Bool?>.Binding
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as ScanSpeechReviewParsingLoadingState: true
        default: false
        }

        DScrollVStack(
            padding: EdgeInsets(
                top: size.s16 + toolbarHeight,
                leading: size.s16,
                bottom: size.s16 + bottomHeight,
                trailing: size.s16,
            ),
        ) {
            DText(
                viewModel.transcriptStatusDescription,
            ).dStyle(
                font: typography.textSmall,
                color: color.grayscaleBackgroundWeak,
            )

            DTextField(
                inputTextController: viewModel.transcriptTextController,
                focus: DTextFieldFocus(
                    value: true,
                    state: transcriptFocus,
                ),
                title: l10n[
                    .scanSpeechReviewFieldTitle,
                ],
                placeholder: l10n[
                    .scanSpeechReviewFieldPlaceholder,
                ],
                mode: DTextFieldMultiLineMode(
                    lineLimit: 6 ... 14,
                ),
                isDisabled:
                isProcessing,
                accessibilityIdentifier: "scanSpeech.transcript",
            )
        }
        .scrollDismissesKeyboard(
            .interactively,
        )
    }
}
