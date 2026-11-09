import DoglyadUI
import SwiftUI

struct ScanCameraPhotoListView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanCameraViewModel

    var body: some View {
        let isLoading = switch viewModel.state {
        case _ as ScanCameraPreparationLoadingState, _ as ScanCameraCaptureLoadingState: true
        default: false
        }

        Group {
            if !viewModel.photos.isEmpty {
                VStack(
                    alignment: .leading,
                    spacing: .zero,
                ) {
                    ScrollView(
                        .horizontal,
                        showsIndicators: false,
                    ) {
                        HStack(
                            spacing: .zero,
                        ) {
                            ForEach(
                                viewModel.photos,
                            ) { photo in
                                DPhotoCard(
                                    image: photo.thumbnail,
                                    configuration: DPhotoCardConfiguration(
                                        badge: .delete(
                                            action: {
                                                viewModel.onTapDeletePhoto(
                                                    photo: photo,
                                                )
                                            },
                                        ),
                                    ),
                                    onTap: {
                                        viewModel.onTapPhoto(
                                            photo,
                                        )
                                    },
                                    isDisabled:
                                    isLoading,
                                    accessibilityIdentifier: "scanCamera.photo.\(photo.id)",
                                )
                                .transition(
                                    .opacity,
                                )
                            }
                        }
                        .padding(
                            .horizontal,
                            size.s16,
                        )
                    }
                    .padding(
                        .bottom,
                        size.s8,
                    )

                    DText(
                        l10n.resource(
                            .scanMaxPhotoDescription,
                            values: [.count: String(
                                viewModel.photoMaxCount,
                            )],
                        ),
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleLine,
                        alignment: .center,
                    )
                    .frame(
                        maxWidth: .infinity,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                }
                .accessibilityIdentifier(
                    "scanCamera.photoCount.\(viewModel.photos.count)",
                )
                .transition(
                    .opacity,
                )
            }
        }
    }
}
