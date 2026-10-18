import DoglyadSpeech
import DoglyadUI
import SwiftUI

struct ScanSpeechModelPreparationView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    var body: some View {
        let preparation: DSpeechModelPreparation = switch viewModel.state {
        case let state as ScanSpeechPreparingModelState: state.preparation
        case _ as ScanSpeechModelPreparationFailedState: .failed
        default: .ready
        }

        VStack(
            spacing: size.s16,
        ) {
            Spacer()

            switch preparation {
            case .checking:
                DText(
                    l10n[
                        .scanSpeechModelCheckingDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                .dShimmer()
            case let .downloading(
                progress,
            ):
                DText(
                    l10n[
                        .scanSpeechModelDownloadDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                if let progress {
                    DText(
                        "\(Int(progress * 100))%",
                    )
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                    DProgress(
                        value: progress,
                    )
                    .dShimmer()
                }
            case .loading:
                DText(
                    l10n[
                        .scanSpeechModelLoadingDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                .dShimmer()
            case .failed:
                DText(
                    l10n[
                        .scanSpeechModelLoadFailedDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.warningDefaultStrong,
                    alignment: .center,
                )
                DButton(
                    title: l10n[
                        .scanSpeechModelRetryButton,
                    ],
                    action: viewModel.onTapRetryModelPreparation,
                )
                .dStyle(
                    .primaryButton,
                )
            case .ready:
                EmptyView()
            }

            Spacer()
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
        .frame(
            maxWidth: .infinity,
        )
    }
}
