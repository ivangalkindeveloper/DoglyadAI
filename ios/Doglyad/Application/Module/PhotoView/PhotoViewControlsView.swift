import DoglyadUI
import SwiftUI

struct PhotoViewControlsView: DView {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PhotoViewViewModel

    var body: some View {
        VStack(
            spacing: size.s8,
        ) {
            DText(
                l10n.resource(
                    .photoViewPageLabel,
                    values: [
                        "current": String(
                            viewModel.currentPage,
                        ),
                        "total": String(
                            viewModel.photos.count,
                        ),
                    ],
                ),
            )
            .dStyle(
                font: typography.textSmall,
                alignment: .center,
            )

            if viewModel.isRemarksToggleVisible {
                HStack(
                    spacing: size.s16,
                ) {
                    DText(
                        l10n[
                            .photoViewShowRemarksLabel,
                        ],
                    ).dStyle(
                        font: typography.textSmall,
                    )
                    DToggle(
                        l10n[
                            .photoViewShowRemarksLabel,
                        ],
                        isOn: Binding(
                            get: { viewModel.isRemarksVisible },
                            set: viewModel.setRemarksVisibility,
                        ),
                    )
                    .labelsHidden()
                }
            }
        }
        .padding(
            size.s16,
        )
        .background(
            DCardBackground(
                cornerRadius: size.adaptiveCardCornerRadius,
                material: .ultraThinMaterial,
            ),
        )
    }
}
