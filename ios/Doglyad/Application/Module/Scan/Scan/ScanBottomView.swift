import DoglyadUI
import SwiftUI

struct ScanBottomView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        let (isGenerationDisabled, isProcessing) = switch viewModel.state {
        case _ as ScanInitializationFailedState: (true, false)
        case _ as ScanInitializationLoadingState, _ as ScanGenerationLoadingState, _ as ScanReportSaveLoadingState, _ as ScanClearLoadingState: (false, true)
        default: (false, false)
        }

        VStack(
            spacing: .zero,
        ) {
            ScanSpeechButtonView()

            DButton(
                title: l10n[
                    .buttonGenerateProtocol,
                ],
                action: viewModel.onTapScan,
                isLoading: isProcessing,
                isDisabled: isGenerationDisabled,
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
