import DoglyadUI
import SwiftUI

struct ScanSpeechModelLoadingView: DView {
    @EnvironmentObject var theme: DTheme
    let description: LocalizedStringResource

    var body: some View {
        Group {
            DShimmerPlaceholder().frame(
                width: size.s64,
                height: size.s8,
            )
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
