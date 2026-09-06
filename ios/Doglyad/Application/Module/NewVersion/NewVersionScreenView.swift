import DoglyadUI
import SwiftUI

struct NewVersionScreenView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: NewVersionViewModel

    var body: some View {
        DScreen(
            title: .newVersionTitle,
            onTapBack: nil,
            content: { toolbarHeight, bottomHeight in
                VStack(
                    spacing: .zero
                ) {
                    Spacer()

                    Image(.doglyadAbout)
                        .resizable()
                        .scaledToFit()

                    DText(.newVersionDescription0)
                        .dStyle(
                            font: typography.linkSmall,
                            alignment: .center
                        )
                        .padding(.bottom, size.s16)

                    DText(.newVersionDescription1)
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscalePlacehold,
                            alignment: .center
                        )

                    Spacer()
                }
                .padding(.top, toolbarHeight)
                .padding(size.s16)
                .padding(.bottom, bottomHeight)
            },
            bottom: {
                DButton(
                    title: .buttonUpdate,
                    action: viewModel.onTapUpdate
                )
                .dStyle(.primaryButton)
                .padding(size.s16)
            }
        )
    }
}
