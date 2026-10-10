import DoglyadUI
import SwiftUI

struct PhotoViewScreenView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: PhotoViewViewModel

    var body: some View {
        DScreen(
            title: l10n[
                .photoViewTitle,
            ],
            subTitle: viewModel.subTitle,
            onTapBack: viewModel.onTapBack,
            trailing: {
                if viewModel.isDeleteButtonVisible {
                    DButton(
                        image: .delete,
                        action: viewModel.onTapDelete,
                    )
                    .dStyle(
                        .circle,
                    )
                    .accessibilityLabel(
                        Text(
                            l10n[
                                .buttonDelete,
                            ],
                        ),
                    )
                }
            },
        ) { toolbarInset, _ in
            ZStack(
                alignment: .bottom,
            ) {
                TabView(
                    selection: $viewModel.selectedPhotoID,
                ) {
                    ForEach(
                        viewModel.photos,
                    ) { photo in
                        PhotoViewZoomableImage(
                            image: photo.image,
                            isSelected: photo.id == viewModel.selectedPhotoID,
                            contentInsets: EdgeInsets(
                                top: toolbarInset + size.s16,
                                leading: size.s16,
                                bottom: size.s16,
                                trailing: size.s16,
                            ),
                        )
                        .tag(
                            photo.id,
                        )
                    }
                }
                .tabViewStyle(
                    .page(
                        indexDisplayMode: .never,
                    ),
                )
                .ignoresSafeArea()

                if viewModel.isPhotoAvailable {
                    HStack(
                        spacing: size.s16,
                    ) {
                        DText(
                            l10n.resource(
                                .photoViewPage,
                                values: ["current": String(
                                    viewModel.currentPage,
                                ), "total": String(
                                    viewModel.photos.count,
                                )],
                            ),
                        )
                        .dStyle(
                            font: typography.textSmall,
                            alignment: .center,
                        )
                    }
                    .padding(
                        size.s16,
                    )
                    .background(
                        RoundedRectangle(
                            cornerRadius: size.adaptiveCardCornerRadius,
                        )
                        .fill(
                            .ultraThinMaterial,
                        ),
                    )
                    .padding(
                        size.s16,
                    )
                }
            }
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onChange(
            of: viewModel.sourcePhotos,
        ) { _, updated in
            viewModel.synchronizePhotos(
                updated,
            )
        }
    }
}
