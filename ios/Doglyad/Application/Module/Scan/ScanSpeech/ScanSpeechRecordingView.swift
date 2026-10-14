import DoglyadUI
import SwiftUI

struct ScanSpeechRecordingView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    var body: some View {
        VStack(
            spacing: .zero,
        ) {
            Spacer()

            if let speechText = viewModel.speechText {
                DText(
                    speechText,
                )
                .dStyle(
                    font: typography.linkSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                .lineLimit(
                    1,
                )
                .truncationMode(
                    .head,
                )
                .clipped()
                .padding(
                    .horizontal,
                    size.s32,
                )
                .padding(
                    .bottom,
                    size.s8,
                )
                .transition(
                    .opacity,
                )
            }

            if viewModel.isAudioMeterVisible {
                ScanSpeechAudioMeterView()
                    .padding(
                        .bottom,
                        size.s16,
                    )
                    .transition(
                        .opacity,
                    )
            }

            if let processingDescription = viewModel.processingDescription {
                DText(
                    processingDescription,
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                .padding(
                    .horizontal,
                    size.s16,
                )
                .padding(
                    .bottom,
                    size.s8,
                )
                .transition(
                    .opacity,
                )
            } else {
                Group {
                    DText(
                        l10n[
                            .scanSpeechProcessDescription,
                        ],
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                    .padding(
                        .bottom,
                        size.s8,
                    )

                    DText(
                        l10n[
                            .scanSpeechProcessSpeechDescription,
                        ],
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                }
                .transition(
                    .opacity,
                )
            }

            Spacer()

            DButton(
                image: viewModel.speechIcon,
                action: viewModel.onTapSpeech,
                isLoading: viewModel.isSpeechButtonLoading,
            )
            .dStyle(
                .primaryCircle,
            )
        }
        .padding(
            size.s16,
        )
    }
}
