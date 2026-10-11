import DoglyadSpeech
import DoglyadUI
import SwiftUI

struct ScanSpeechModelPreparationView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    let state: DSpeechModelPreparation
    let onRetry: () -> Void

    var body: some View {
        VStack(
            spacing: size.s16,
        ) {
            Spacer()

            switch state {
            case .checking:
                ScanSpeechModelLoadingView(
                    description: l10n[
                        .scanSpeechModelCheckingDescription,
                    ],
                )
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
            case .loading:
                ScanSpeechModelLoadingView(
                    description: l10n[
                        .scanSpeechModelLoadingDescription,
                    ],
                )
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
                    action: onRetry,
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
