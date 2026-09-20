import DoglyadUI
import SwiftUI

struct PhotoViewScreenView: DView {
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: PhotoViewViewModel

    var body: some View {
        DScreen(
            title: .photoViewTitle,
            subTitle: viewModel.subTitle,
            onTapBack: viewModel.onTapBack,
            trailing: {
                if viewModel.isDeleteButtonVisible {
                    DButton(
                        image: .delete,
                        action: viewModel.onTapDelete
                    )
                    .dStyle(.circle)
                    .accessibilityLabel(Text(.buttonDelete))
                }
            }
        ) { toolbarInset, _ in
            ZStack(
                alignment: .bottom
            ) {
                TabView(
                    selection: $viewModel.selectedPhotoID
                ) {
                    ForEach(viewModel.photos) { photo in
                        PhotoViewZoomableImage(
                            image: photo.image,
                            isSelected: photo.id == viewModel.selectedPhotoID,
                            contentInsets: EdgeInsets(
                                top: toolbarInset + size.s16,
                                leading: size.s16,
                                bottom: size.s16,
                                trailing: size.s16
                            )
                        )
                        .tag(photo.id)
                    }
                }
                .tabViewStyle(
                    .page(indexDisplayMode: .never)
                )
                .ignoresSafeArea()

                if viewModel.isPhotoAvailable {
                    HStack(
                        spacing: size.s16
                    ) {
                        DText(
                            .photoViewPage(
                                current: viewModel.currentPage,
                                total: viewModel.photos.count
                            )
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: .white,
                            alignment: .center
                        )
                    }
                    .padding(size.s16)
                    .background(
                        RoundedRectangle(
                            cornerRadius: size.adaptiveCardCornerRadius
                        )
                        .fill(.ultraThinMaterial)
                    )
                    .padding(size.s16)
                }
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .onChange(of: viewModel.sourcePhotos) { _, updated in
            viewModel.synchronizePhotos(updated)
        }
    }
}
