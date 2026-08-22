import DoglyadUI
import SwiftUI

struct RecievedConclusionBottomSheetView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }

    @StateObject var viewModel: RecievedConclusionViewModel

    var body: some View {
        DBottomSheet(
            type: .blur,
            title: .conclusionTitle,
            fraction: 1,
            content: { toolbarHeight, bottomHeight in
                VStack(
                    spacing: .zero
                ) {
                    ScrollView {
                        RecievedConclusionMarkdownView(
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
                        title: .buttonToConclusion,
                        action: viewModel.onTapConclusion
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
        .onAppear {
            viewModel.onAppear()
        }
    }
}
