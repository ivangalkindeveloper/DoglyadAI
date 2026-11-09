import DoglyadSpeech
import DoglyadUI
import SwiftUI

struct ScanSpeechModelPreparationStatusView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let preparation: DSpeechModelPreparationStatus
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    var body: some View {
        let (descriptionKey, descriptionColor, progress): (L10NKey?, Color, Double?) = switch preparation {
        case .checking: (.scanSpeechModelCheckingDescription, color.grayscaleBackgroundWeak, 0)
        case let .downloading(
            progress,
        ): (.scanSpeechModelDownloadDescription, color.grayscaleBackgroundWeak, progress ?? 0)
        case .loading: (.scanSpeechModelLoadingDescription, color.grayscaleBackgroundWeak, 1)
        case .failed: (.scanSpeechModelLoadFailedDescription, color.grayscaleBackgroundWeak, nil)
        case .ready: (nil, color.grayscaleBackgroundWeak, nil)
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
                ).dStyle(
                    font: typography.textSmall,
                    color: descriptionColor,
                    alignment: .center,
                )
            }

            if let progress {
                DText(
                    "\(Int(progress * 100))%",
                ).dStyle(
                    font: typography.linkSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )

                DProgress(
                    value: progress,
                ).dShimmer()
            }

            Spacer()
        }.padding(
            size.s16,
        ).padding(
            .top,
            toolbarHeight,
        ).padding(
            .bottom,
            bottomHeight,
        ).frame(
            maxWidth: .infinity,
        )
    }
}
