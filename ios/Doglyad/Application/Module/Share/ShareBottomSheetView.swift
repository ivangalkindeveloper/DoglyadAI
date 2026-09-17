import DoglyadUI
import SwiftUI

struct ShareBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ShareViewModel

    var body: some View {
        DBottomSheet(
            title: .shareTitle,
            fraction: viewModel.isUserEmailAvailable && viewModel.isUserEmailButtonVisible ? 0.4 : 0.3
        ) { toolbarHeight, _ in
            VStack(
                spacing: size.s8
            ) {
                if viewModel.isUserEmailAvailable && viewModel.isUserEmailButtonVisible {
                    DButtonCard(
                        action: viewModel.onTapUserEmail
                    ) {
                        HStack(
                            spacing: size.s8
                        ) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .transition(.opacity)
                            } else {
                                DIcon(
                                    .send,
                                    color: color.grayscaleHeader
                                )
                                .transition(.opacity)
                            }
                            DText(viewModel.userEmailButtonTitle)
                                .dStyle(
                                    font: typography.linkSmall
                                )
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .paidBadge(.sendingReportByEmail)
                    .transition(.opacity)
                }

                if viewModel.isUserEmailButtonVisible {
                    DButtonCard(
                        action: viewModel.onTapEmail
                    ) {
                        row(
                            icon: .mail,
                            title: .buttonShareEmail
                        )
                    }
                    .disabled(viewModel.isLoading)
                    .paidBadge(.sendingReportByEmail)
                    .transition(.opacity)
                }

                DButtonCard(
                    action: viewModel.onTapCopy
                ) {
                    row(
                        icon: .copy,
                        title: .buttonCopy
                    )
                }
                .disabled(viewModel.isLoading)

                ShareLink(
                    item: viewModel.shareMessage
                ) {
                    row(
                        icon: .export,
                        title: .buttonShare
                    )
                }
                .buttonStyle(DButtonStyle(.card))
                .disabled(viewModel.isLoading)

                Spacer()
            }
            .padding(.top, toolbarHeight + size.s16)
            .padding(.horizontal, size.s16)
        }
        .animation(theme.animation, value: viewModel.isLoading)
        .animation(theme.animation, value: viewModel.isUserEmailButtonVisible)
        .onAppear(perform: viewModel.onAppear)
    }

    private func row(
        icon: ImageResource,
        title: LocalizedStringResource
    ) -> some View {
        HStack(
            spacing: size.s8
        ) {
            DIcon(
                icon,
                color: color.grayscaleHeader
            )
            DText(title)
                .dStyle(
                    font: typography.linkSmall
                )
            Spacer()
        }
    }
}
