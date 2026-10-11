import DoglyadUI
import SwiftUI

struct ActionRowView: DView {
    @EnvironmentObject var theme: DTheme
    let icon: ImageResource
    let title: LocalizedStringResource

    var body: some View {
        HStack(
            spacing: size.s8,
        ) {
            DIcon(
                icon,
                color: color.grayscaleHeader,
            )
            DText(
                title,
            )
            .dStyle(
                font: typography.linkSmall,
            )
            Spacer()
        }
    }
}
