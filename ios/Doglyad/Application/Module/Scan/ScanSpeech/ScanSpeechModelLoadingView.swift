import DoglyadUI
import SwiftUI

struct ScanSpeechModelLoadingView: DView {
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    var body: some View {
        Group {
            DShimmerPlaceholder().frame(
                width: size.s64,
                height: size.s8,
            )
            .tint(
                color.primaryDefault,
            )
            if let description = viewModel.modelPreparationLoadingDescription {
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
