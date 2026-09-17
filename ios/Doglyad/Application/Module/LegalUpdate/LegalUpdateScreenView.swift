import DoglyadUI
import SwiftUI

struct LegalUpdateScreenView: DView {
    @Environment(\.locale) private var locale
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: LegalUpdateViewModel

    var body: some View {
        DScreen(
            title: .legalUpdateTitle,
            content: { toolbarHeight, bottomHeight in
                VStack(
                    alignment: .leading,
                    spacing: size.s16
                ) {
                    Spacer()

                    Image(.doglyadQuiet)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .center
                        )
                        .padding(size.s16)

                    Spacer()

                    DText(.legalUpdateDescription)
                        .dStyle(
                            font: typography.textMedium
                        )

                    HStack(
                        alignment: .center
                    ) {
                        DCheckbox(
                            isChecked: Binding(
                                get: { viewModel.isLegalAccepted },
                                set: viewModel.onLegalAcceptedChanged
                            )
                        )
                        .padding(.trailing, size.s8)

                        Text(viewModel.legalAttributedText(theme: theme, locale: locale))
                            .multilineTextAlignment(.leading)
                            .tint(color.grayscaleHeader)
                            .environment(\.openURL, OpenURLAction { url in
                                viewModel.onLegalAttributedEnvironment(url: url)
                            })
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, size.s8)
                }
                .padding(.top, toolbarHeight)
                .padding(size.s16)
                .padding(.bottom, bottomHeight)
            },
            bottom: {
                DButton(
                    title: .buttonAccept,
                    action: viewModel.onTapAccept,
                    isDisabled: viewModel.isAcceptDisabled
                )
                .dStyle(.primaryButton)
                .padding(size.s16)
            }
        )
        .animation(theme.animation, value: viewModel.isLegalAccepted)
        .onAppear(perform: viewModel.onAppear)
    }
}
