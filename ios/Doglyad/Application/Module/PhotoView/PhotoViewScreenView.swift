import DoglyadUI
import SwiftUI

struct PhotoViewScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: PhotoViewViewModel
    @State private var controlsHeight: CGFloat = 0

    var body: some View {
        DScreen(
            title: l10n[
                .photoViewTitle,
            ],
            subTitle: viewModel.subTitle,
            onTapBack: viewModel.onTapBack,
            trailing: {
                switch viewModel.isDeletionAvailable {
                case true:
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
                case false: EmptyView()
                }
            },
        ) { toolbarInset, _ in
            ZStack(
                alignment: .bottom,
            ) {
                TabView(
                    selection: Binding(
                        get: { viewModel.selectedPhotoID },
                        set: viewModel.onPhotoSelected,
                    ),
                ) {
                    ForEach(
                        viewModel.photos,
                    ) { photo in
                        PhotoViewZoomableImage(
                            photoId: photo.id,
                            image: photo.image,
                            isSelected: photo.id == viewModel.selectedPhotoID,
                            contentInsets: EdgeInsets(
                                top: toolbarInset + size.s16,
                                leading: size.s16,
                                bottom: controlsHeight + size.s16,
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

                switch viewModel.state {
                case _ as PhotoViewContentState:
                    PhotoViewControlsView()
                        .padding(
                            size.s16,
                        )
                        .onGeometryChange(
                            for: CGFloat.self,
                            of: { $0.size.height },
                        ) { height in
                            controlsHeight = height
                        }
                case _ as PhotoViewEmptyState: EmptyView()
                default: DUnexpectedStateView(
                        state: viewModel.state,
                    )
                }
            }
        }
        .environmentObject(
            viewModel,
        )
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
