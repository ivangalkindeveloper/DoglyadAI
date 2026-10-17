import DoglyadUI
import SwiftUI

struct ScanSpeechModelLoadingView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    var body: some View {
        let description: LocalizedStringResource? = switch viewModel.state {
        case let state as ScanSpeechPreparingModelState:
            switch state.preparation {
            case .checking: l10n[
                    .scanSpeechModelCheckingDescription,
                ]
            case .loading: l10n[
                    .scanSpeechModelLoadingDescription,
                ]
            case .downloading, .failed, .ready: nil
            }
        default: nil
        }

        Group {
            DShimmerPlaceholder().frame(
                width: size.s64,
                height: size.s8,
            )
            .tint(
                color.primaryDefault,
            )
            if let description {
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
}
