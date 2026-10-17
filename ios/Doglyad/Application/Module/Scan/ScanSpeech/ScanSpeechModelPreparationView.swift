import DoglyadSpeech
import DoglyadUI
import SwiftUI

struct ScanSpeechModelPreparationView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

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
            case .checking, .loading:
                ScanSpeechModelLoadingView()
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
                    DProgress(
                        value: progress,
                    )
                    .tint(
                        color.primaryDefault,
                    )
                    DText(
                        "\(Int(progress * 100))%",
                    )
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                } else {
                    DShimmerPlaceholder().frame(
                        width: size.s64,
                        height: size.s8,
                    )
                    .tint(
                        color.primaryDefault,
                    )
                }
            case .failed:
                DText(
                    l10n[
                        .scanSpeechModelLoadFailedDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
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
        .frame(
            maxWidth: .infinity,
        )
    }
}
