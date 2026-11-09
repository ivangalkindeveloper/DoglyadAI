import DoglyadUI
import SwiftUI

struct ScanBottomView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as ScanGenerationLoadingState: true
        default: false
        }

        VStack(
            spacing: .zero,
        ) {
            ScanSpeechButtonView()

            Group {
                DButton(
                    title: l10n[
                        .buttonGenerateProtocol,
                    ],
                    action: viewModel.onTapScan,
                    isLoading: isProcessing,
                    accessibilityIdentifier: "scan.generate",
                )
                .dStyle(
                    .primaryButton,
                )
                .padding(
                    size.s16,
                )
                .background(
                    DCardBackground(
                        cornerRadius: 0,
                        material: .ultraThinMaterial,
                    )
                    .clipShape(
                        DRoundedCorner(
                            radius: size.adaptiveCornerRadius,
                            corners: [.topLeft, .topRight],
                        ),
                    )
                    .ignoresSafeArea(
                        .container,
                        edges: .bottom,
                    ),
                )
            }
        }
    }
}
