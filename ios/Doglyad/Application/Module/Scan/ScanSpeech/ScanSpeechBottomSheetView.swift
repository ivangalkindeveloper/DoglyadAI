import DoglyadUI
import SwiftUI

struct ScanSpeechBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ScanSpeechViewModel

    var body: some View {
        DBottomSheet(
            type: viewModel.isReviewVisible ? .default : .blur,
            title: .speechTitle,
            fraction: viewModel.isReviewVisible ? 0.85 : 0.5,
        ) { toolbarHeight, _ in
            Group {
                if viewModel.isProposalVisible {
                    ScanSpeechProposalView(
                        viewModel: viewModel,
                    )
                } else if viewModel.isReviewVisible {
                    ScanSpeechReviewView(
                        viewModel: viewModel,
                    )
                } else if !viewModel.isModelReady {
                    ScanSpeechModelPreparationView(
                        state: viewModel.modelPreparation,
                        onRetry: viewModel.onTapRetryModelPreparation,
                    )
                } else {
                    recordingContent
                }
            }
            .padding(
                .top,
                toolbarHeight,
            )
        }
        .animation(
            theme.animation,
            value: viewModel.speechController.status,
        )
        .animation(
            theme.animation,
            value: viewModel.isReviewVisible,
        )
        .animation(
            theme.animation,
            value: viewModel.isModelReady,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
    }

    private var recordingContent: some View {
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
                ScanSpeechAudioMeterView(
                    level: viewModel.audioMeterLevel,
                )
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
                        .speechProcessDescription,
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
                        .speechProcessSpeechDescription,
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
