import DoglyadUI
import SwiftUI

struct ScanSpeechTranscriptionErrorView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    init(
        toolbarHeight: CGFloat,
        bottomHeight: CGFloat,
    ) {
        self.toolbarHeight = toolbarHeight
        self.bottomHeight = bottomHeight
    }

    var body: some View {
        VStack {
            Spacer()

            DText(
                l10n[
                    .scanSpeechTranscriptionRetainedDescription,
                ],
            ).dStyle(
                font: typography.textSmall,
                color: color.grayscaleBackgroundWeak,
                alignment: .center,
            )

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
