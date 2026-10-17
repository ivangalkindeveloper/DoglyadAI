import DoglyadUI
import SwiftUI

struct PhotoViewControlsView: DViewProtocol {
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

            switch viewModel.remarkPoints(
                for: viewModel.selectedPhotoID,
            ).isEmpty {
            case false:
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
            case true: EmptyView()
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
