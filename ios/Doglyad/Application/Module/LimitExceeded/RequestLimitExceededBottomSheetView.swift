import DoglyadUI
import SwiftUI

struct RequestLimitExceededBottomSheetView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: RequestLimitViewModel

    var body: some View {
        DBottomSheet(
            title: .requestLimitExceededTitle,
            isCloseButtonVisible: false,
            fraction: 0.3
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero
            ) {
                DText(.requestLimitExceededDescription)
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscalePlacehold,
                        alignment: .center
                    )
                    .padding(.top, toolbarHeight + size.s24)
                    .padding(.horizontal, size.s16)
                Spacer()
            }
        } bottom: {
            VStack(
                spacing: size.s8
            ) {
                DButton(
                    title: .settingsSubscriptionManageTitle,
                    action: viewModel.onTapUpgrade
                )
                .dStyle(.primaryButton)
                DButton(
                    title: .buttonBack,
                    action: viewModel.onTapBack
                )
                .dStyle(.card)
            }
            .padding(.horizontal, size.s16)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
