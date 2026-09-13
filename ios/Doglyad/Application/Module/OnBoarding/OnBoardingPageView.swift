import DoglyadUI
import SwiftUI

struct OnBoardingPageView<BottomContent: View>: DView {
    @EnvironmentObject var theme: DTheme

    let tag: OnBoardingViewModel.Page
    let title: LocalizedStringResource
    let image: ImageResource
    let description: LocalizedStringResource
    let bottomContent: BottomContent

    init(
        tag: OnBoardingViewModel.Page,
        title: LocalizedStringResource,
        image: ImageResource,
        description: LocalizedStringResource,
        @ViewBuilder bottomContent: @escaping () -> BottomContent = { EmptyView() }
    ) {
        self.tag = tag
        self.title = title
        self.image = image
        self.description = description
        self.bottomContent = bottomContent()
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero
        ) {
            DText(title)
                .dStyle(
                    font: typography.displayLargeBold
                )
                .padding(.bottom, size.s16)

            Spacer()

            Image(image)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .padding(size.s16)

            Spacer()

            DText(
                description
            )
            .dStyle(
                font: typography.textMedium,
                alignment: .leading
            )

            if !(bottomContent is EmptyView) {
                bottomContent
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .tag(tag)
    }
}
