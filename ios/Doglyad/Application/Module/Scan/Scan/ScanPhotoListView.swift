import DoglyadUI
import SwiftUI

struct ScanPhotoListView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        let isMediaSelectionDisabled = switch (viewModel.state, viewModel.isPhotoLimitReached) {
        case (_ as ScanInitializingState, _), (_ as ScanGeneratingState, _), (_ as ScanLoadingState, _), (_ as ScanClearingState, _), (_, true): true
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
                            if !viewModel.isPhotoLimitReached {
                                ScanMediaButtonView(
                                    isCompact: true,
                                    action: viewModel.onTapImport,
                                )
                                .disabled(
                                    isMediaSelectionDisabled,
                                )
                                .padding(
                                    .trailing,
                                    size.s8,
                                )
                                .transition(
                                    .opacity,
                                )
                            }

                            ForEach(
                                Array(
                                    viewModel.photos.enumerated(),
                                ),
                                id: \.element.id,
                            ) { index, photo in
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
                                    accessibilityIdentifier: "scan.photo.\(index + 1).\(photo.id)",
                                    onTap: {
                                        viewModel.onTapPhoto(
                                            photo,
                                        )
                                    },
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
                        color: color.grayscalePlacehold,
                        alignment: .center,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                }
                .padding(
                    .bottom,
                    size.s8,
                )
                .transition(
                    .opacity,
                )
            }
        }
    }
}
