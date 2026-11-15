import DoglyadUI
import SwiftUI

struct ScanSpeechReviewTranscriptView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    let isTranscriptFocused: FocusState<Bool?>.Binding
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    init(
        isTranscriptFocused: FocusState<Bool?>.Binding,
        toolbarHeight: CGFloat,
        bottomHeight: CGFloat,
    ) {
        self.isTranscriptFocused = isTranscriptFocused
        self.toolbarHeight = toolbarHeight
        self.bottomHeight = bottomHeight
    }

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
                    state: isTranscriptFocused,
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
