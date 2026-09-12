import DoglyadUI
import SwiftUI

struct ScanSheetFooterView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }

    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        VStack(
            spacing: .zero
        ) {
            Spacer()
            if viewModel.sheetController.isTop {
                VStack(
                    spacing: .zero
                ) {
                    if viewModel.isSpeechButtonVisible {
                        if !viewModel.isLoading {
                            DButton(
                                image: .microphone,
                                title: .buttonSpeech,
                                action: viewModel.onTapSpeech
                            )
                            .dStyle(.primaryChip)
                            .paidBadge(.formCompletionViaMicrophone)
                            .padding(.bottom, size.s8)
                            .transition(.move(edge: .bottom))
                        }
                    }

                    DButton(
                        title: .buttonGenerate,
                        action: viewModel.onTapScan,
                        isLoading: viewModel.isLoading
                    )
                    .dStyle(.primaryButton)
                    .padding(size.s16)
                    .safeAreaPadding(.bottom)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .clipShape(
                                DRoundedCorner(
                                    radius: size.adaptiveCornerRadius,
                                    corners: [.topLeft, .topRight]
                                )
                            )
                    )
                }
                .transition(.move(edge: .bottom))
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .animation(
            theme.animation,
            value: viewModel.sheetController.currentPosition
        )
        .animation(
            theme.animation,
            value: viewModel.isLoading
        )
    }
}
