import DoglyadUI
import SwiftUI

struct ScanSpeechReviewParsingView: DViewProtocol {
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
            .padding(
                .horizontal,
                size.s16,
            )
            .padding(
                .top,
                toolbarHeight + size.s16,
            )
            .padding(
                .bottom,
                max(
                    .zero,
                    bottomHeight,
                ) + size.s16,
            )
        }
        .scrollDismissesKeyboard(
            .interactively,
        )
    }
}
