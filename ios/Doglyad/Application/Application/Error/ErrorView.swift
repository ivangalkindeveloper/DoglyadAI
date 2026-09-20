import DoglyadUI
import SwiftUI

struct ErrorView<Description: View>: DView {
    @EnvironmentObject private var applicationViewModel: ApplicationViewModel
    @EnvironmentObject var theme: DTheme

    private let title: LocalizedStringResource
    private let buttonTitle: LocalizedStringResource?
    private let action: (() -> Void)?
    private let description: () -> Description

    init(
        title: LocalizedStringResource,
        buttonTitle: LocalizedStringResource? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder description: @escaping () -> Description
    ) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.action = action
        self.description = description
    }

    @ViewBuilder
    var body: some View {
        if let buttonTitle, let action {
            DScreen { _, bottomInset in
                content(bottomInset: bottomInset)
            } bottom: {
                DButton(
                    title: buttonTitle,
                    action: action,
                    isLoading: applicationViewModel.isLoading
                )
                .dStyle(.primaryButton)
                .padding(size.s16)
            }
        } else {
            DScreen { _, _ in
                content()
            }
        }
    }

    private func content(
        bottomInset: CGFloat = .zero
    ) -> some View {
        VStack(
            alignment: .center,
            spacing: .zero
        ) {
            Spacer()

            Image(.doglyadQuestion)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
                .padding(size.s16)

            DText(title)
                .dStyle(
                    font: typography.linkMedium,
                    alignment: .center
                )
                .padding(.bottom, size.s16)

            description()
                .font(typography.textSmall)
                .foregroundStyle(color.grayscalePlacehold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, size.s14)
                .padding(.bottom, size.s16)

            Spacer()
        }
        .padding(size.s16)
        .padding(.bottom, bottomInset)
    }
}
