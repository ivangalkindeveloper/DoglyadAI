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
        let preparation: DSpeechModelPreparationStatus = switch viewModel.state {
        case let state as ScanSpeechPreparingModelState: state.preparation
        case _ as ScanSpeechModelPreparationFailedState: .failed
        default: .ready
        }
        let descriptionKey: L10NKey? = switch preparation {
        case .checking: .scanSpeechModelCheckingDescription
        case .downloading: .scanSpeechModelDownloadDescription
        case .loading: .scanSpeechModelLoadingDescription
        case .failed: .scanSpeechModelLoadFailedDescription
        case .ready: nil
        }
        let descriptionColor: Color = switch preparation {
        case .checking, .downloading, .loading, .ready: color.grayscaleBackgroundWeak
        case .failed: color.warningDefaultStrong
        }
        let progress: Double? = switch preparation {
        case .checking: 0
        case let .downloading(
            progress,
        ): progress ?? 0
        case .loading: 1
        case .ready, .failed: nil
        }

        VStack(
            spacing: size.s16,
        ) {
            Spacer()

            if let descriptionKey {
                DText(
                    l10n[
                        descriptionKey,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: descriptionColor,
                    alignment: .center,
                )
            }

            switch preparation {
            case .failed:
                DButton(
                    title: l10n[
                        .scanSpeechModelRetryButton,
                    ],
                    action: viewModel.onTapRetryModelPreparation,
                )
                .dStyle(
                    .primaryButton,
                )
            case .checking, .downloading, .loading, .ready:
                EmptyView()
            }

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
