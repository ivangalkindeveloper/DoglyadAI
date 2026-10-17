import SwiftUI

struct DBadgeItemView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let badge: DBadgeItem

    var body: some View {
        Text(
            badge.title,
        )
        .font(
            typography.linkXSmall,
        )
        .foregroundStyle(
            color.grayscaleBackground,
        )
        .lineLimit(
            1,
        )
        .fixedSize(
            horizontal: true,
            vertical: false,
        )
        .padding(
            .horizontal,
            size.s8,
        )
        .padding(
            .vertical,
            size.s2,
        )
        .background(
            Capsule()
                .fill(
                    color.gradientPrimary,
                ),
        )
    }
}
