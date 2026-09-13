import DoglyadUI
import SwiftUI

struct ScanBottomView: DView {
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
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
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .clipShape(
                        DRoundedCorner(
                            radius: size.adaptiveCornerRadius,
                            corners: [.topLeft, .topRight]
                        )
                    )
                    .ignoresSafeArea(.container, edges: .bottom)
            )
        }
        .animation(
            theme.animation,
            value: viewModel.isLoading
        )
    }
}
