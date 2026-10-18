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

        ScrollView(
            showsIndicators: false,
        ) {
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

#if DEBUG
    #Preview(
        "Диктовка готова",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .finished,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Длинная прерванная запись",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .interrupted,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Речь не распознана",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .failed,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Разбор диктовки",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .parsing,
        )
        .dMessage()
        .dThemeWrapper()
    }
#endif
