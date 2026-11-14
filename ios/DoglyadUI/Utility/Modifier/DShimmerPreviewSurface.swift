import SwiftUI

struct DShimmerPreviewSurface: View {
    let label: String
    let cornerRadius: CGFloat
    var height: CGFloat = 56

    init(
        label: String,
        cornerRadius: CGFloat,
        height: CGFloat = 56,
    ) {
        self.label = label
        self.cornerRadius = cornerRadius
        self.height = height
    }

    var body: some View {
        RoundedRectangle(
            cornerRadius: cornerRadius,
        )
        .fill(
            LinearGradient(
                colors: [.blue, .indigo],
                startPoint: .leading,
                endPoint: .trailing,
            ),
        )
        .frame(
            height: height,
        )
        .overlay {
            Text(
                label,
            )
            .font(
                .footnote.weight(
                    .semibold,
                ),
            )
            .foregroundStyle(
                .white,
            )
        }
    }
}
