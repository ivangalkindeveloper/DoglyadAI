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
            switch viewModel.photos.isEmpty {
            case false:
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
                            switch viewModel.isPhotoLimitReached {
                            case false:
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
                            case true: EmptyView()
                            }

                            ForEach(
                                viewModel.photos,
                            ) { photo in
                                PhotoCardView(
                                    image: photo.thumbnail,
                                    configuration: PhotoCardConfiguration(
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
                            values: ["count": String(
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
            case true: EmptyView()
            }
        }
    }
}
