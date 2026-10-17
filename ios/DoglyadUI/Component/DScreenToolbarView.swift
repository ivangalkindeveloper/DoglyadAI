import SwiftUI

struct DScreenToolbarView<Leading: View, Title: View, Trailing: View, Content: View>: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let safeAreaInsetTop: CGFloat
    let leadingView: Leading
    let titleView: Title
    let trailingView: Trailing
    let toolbarContent: Content

    var body: some View {
        VStack(
            spacing: .zero,
        ) {
            VStack(
                spacing: .zero,
            ) {
                HStack(
                    spacing: .zero,
                ) {
                    leadingView
                    Spacer()
                    titleView
                    Spacer()
                    trailingView
                }
                .padding(
                    .top,
                    size.s2 + safeAreaInsetTop,
                )
                .padding(
                    .horizontal,
                    size.adaptiveCornerRadius / 4,
                )

                toolbarContent
            }
            .padding(
                .bottom,
                size.adaptiveCornerRadius / 4,
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .top,
        )
        .background {
            Rectangle()
                .fill(
                    .ultraThinMaterial,
                )
                .clipShape(
                    DRoundedCorner(
                        radius: size.adaptiveCornerRadius,
                        corners: [.bottomLeft, .bottomRight],
                    ),
                )
        }
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: DScreenToolbarHeightPreferenceKey.self,
                        value: proxy.size.height,
                    )
            }
        }
    }
}
