import DoglyadUI
import SwiftUI

struct ScanSpeechReviewTranscriptView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as ScanSpeechReviewParsingState: true
        default: false
        }

        ScrollView {
            VStack(
                alignment: .leading,
                spacing: size.s16,
            ) {
                DText(
                    viewModel.transcriptStatusDescription,
                ).dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                )
                DTextField(
                    inputTextController: viewModel.transcriptTextController,
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
        .scrollDismissesKeyboard(
            .interactively,
        )
    }
}
