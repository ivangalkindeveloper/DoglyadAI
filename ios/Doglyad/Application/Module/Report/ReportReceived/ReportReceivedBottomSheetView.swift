import DoglyadUI
import SwiftUI

struct ReportReceivedBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ReportReceivedViewModel

    var body: some View {
        DBottomSheet(
            type: .blur,
            title: .reportTitle,
            fraction: 1,
            content: { toolbarHeight, bottomHeight in
                VStack(
                    spacing: .zero
                ) {
                    ScrollView {
                        ReportReceivedMarkdownView(
                            viewModel: viewModel.markdownViewModel,
                            textColor: color.grayscaleBackgroundWeak
                        )
                        .padding(.top, toolbarHeight)
                        .padding(size.s16)
                        .padding(.bottom, bottomHeight)
                    }
                    .mask(
                        VStack(
                            spacing: .zero
                        ) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: size.s16)

                            Color.black
                        }
                    )
                }
            },
            bottom: {
                VStack(
                    spacing: size.s8
                ) {
                    DButton(
                        title: .buttonToReport,
                        action: viewModel.onTapReport
                    )
                    .dStyle(.primaryButton)

                    if viewModel.isUserEmailAvailable && viewModel.isUserEmailButtonVisible {
                        DButton(
                            image: .send,
                            title: viewModel.userEmailButtonTitle,
                            badge: viewModel.userEmailButtonBadge,
                            action: viewModel.onTapUserEmail,
                            isLoading: viewModel.isLoading
                        )
                        .dStyle(.textWeak)
                        .transition(.opacity)
                    }

                    DButton(
                        image: .copy,
                        title: .buttonCopy,
                        action: viewModel.onTapCopy
                    )
                    .dStyle(.textWeak)
                    .padding(.bottom, size.s10)
                }
                .padding(.top, size.s8)
                .padding(.horizontal, size.s16)
            }
        )
        .animation(theme.animation, value: viewModel.isUserEmailButtonVisible)
        .onAppear {
            viewModel.onAppear()
        }
    }
}
