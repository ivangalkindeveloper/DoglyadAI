import DoglyadUI
import SwiftUI

struct ScanSpeechRecordingView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    var body: some View {
        let icon: ImageResource = switch viewModel.state {
        case _ as ScanSpeechReadyState: .play
        default: .check
        }
        let isProcessing = switch viewModel.state {
        case _ as ScanSpeechPreparingRecordingState, _ as ScanSpeechPreparingModelState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechTranscribingState, _ as ScanSpeechAutomaticParsingState: true
        default: false
        }
        let description: LocalizedStringResource? = switch viewModel.state {
        case _ as ScanSpeechPreparingRecordingState: l10n[
                .scanSpeechProcessPreparingDescription,
            ]
        case _ as ScanSpeechTranscribingState: l10n[
                .scanSpeechProcessTranscribingDescription,
            ]
        default: nil
        }
        VStack(
            spacing: .zero,
        ) {
            Spacer()
            switch viewModel.state {
            case _ as ScanSpeechRecordingState:
                switch viewModel.controller.text {
                case let .some(
                    text,
                ):
                    DText(
                        text,
                    ).dStyle(
                        font: typography.linkSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                    .lineLimit(
                        1,
                    ).truncationMode(
                        .head,
                    ).clipped().padding(
                        .horizontal,
                        size.s32,
                    ).padding(
                        .bottom,
                        size.s8,
                    ).transition(
                        .opacity,
                    )
                case .none: EmptyView()
                }
                ScanSpeechAudioMeterView().padding(
                    .bottom,
                    size.s16,
                ).transition(
                    .opacity,
                )
            default: EmptyView()
            }
            switch description {
            case let .some(
                description,
            ):
                DText(
                    description,
                ).dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                .padding(
                    .horizontal,
                    size.s16,
                ).padding(
                    .bottom,
                    size.s8,
                ).transition(
                    .opacity,
                )
            case .none:
                Group {
                    DText(
                        l10n[
                            .scanSpeechProcessDescription,
                        ],
                    ).dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    ).padding(
                        .bottom,
                        size.s8,
                    )
                    DText(
                        l10n[
                            .scanSpeechProcessSpeechDescription,
                        ],
                    ).dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                }.transition(
                    .opacity,
                )
            }
            Spacer()
            DButton(
                image: icon,
                action: viewModel.onTapSpeech,
                isLoading: isProcessing,
            ).dStyle(
                .primaryCircle,
            )
        }.padding(
            size.s16,
        )
    }
}
