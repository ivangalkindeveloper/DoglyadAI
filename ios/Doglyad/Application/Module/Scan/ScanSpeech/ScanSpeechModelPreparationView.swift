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
                loadingContent(
                    description: l10n[
                        .speechModelCheckingDescription,
                    ],
                )
            case let .downloading(
                progress,
            ):
                DText(
                    l10n[
                        .speechModelDownloadDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                if let progress {
                    ProgressView(
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
                    ProgressView()
                        .tint(
                            color.primaryDefault,
                        )
                }
            case .loading:
                loadingContent(
                    description: l10n[
                        .speechModelLoadingDescription,
                    ],
                )
            case .failed:
                DText(
                    l10n[
                        .speechModelLoadFailedDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                DButton(
                    title: l10n[
                        .speechModelRetryButton,
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

    private func loadingContent(
        description: LocalizedStringResource,
    ) -> some View {
        Group {
            ProgressView()
                .tint(
                    color.primaryDefault,
                )
            DText(
                description,
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscaleBackgroundWeak,
                alignment: .center,
            )
        }
    }
}
