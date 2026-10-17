import DoglyadUI
import SwiftUI

struct ScanBottomView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        let isGenerationDisabled = switch viewModel.state {
        case _ as ScanInitializationFailedState: true
        default: false
        }

        let isProcessing = switch viewModel.state {
        case _ as ScanInitializingState, _ as ScanGeneratingState, _ as ScanLoadingState, _ as ScanClearingState: true
        default: false
        }

        VStack(
            spacing: .zero,
        ) {
            switch viewModel.subscriptionAvailability(
                of: .formCompletionViaMicrophone,
            ) {
            case .available, .offered:
                switch viewModel.state {
                case _ as ScanInitializingState, _ as ScanGeneratingState, _ as ScanLoadingState, _ as ScanClearingState, _ as ScanInitializationFailedState: EmptyView()
                default:
                    DButton(
                        image: .microphone,
                        title: l10n[
                            .buttonSpeech,
                        ],
                        action: viewModel.onTapSpeech,
                    )
                    .dStyle(
                        .primaryChip,
                    )
                    .paidBadge(
                        viewModel.subscriptionAvailability(
                            of: .formCompletionViaMicrophone,
                        ),
                    )
                    .padding(
                        .bottom,
                        size.s8,
                    )
                    .transition(
                        .move(
                            edge: .bottom,
                        ),
                    )
                }
            case .unavailable: EmptyView()
            }

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
