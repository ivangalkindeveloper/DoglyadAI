import DoglyadUI
import SwiftUI

struct PhotoViewScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: PhotoViewViewModel
    @State private var controlsHeight: CGFloat = 0

    init(
        viewModel: @autoclosure @escaping () -> PhotoViewViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DScreen(
            title: l10n[
                .photoViewTitle,
            ],
            subTitle: viewModel.subTitle,
            onTapBack: viewModel.onTapBack,
            trailing: {
                if viewModel.isDeletionAvailable {
                    DButton(
                        image: .delete,
                        action: viewModel.onTapDelete,
                        accessibilityIdentifier: "photoView.delete",
                    )
                    .dStyle(
                        .circle,
                    )
                }
            },
        ) { toolbarInset, _ in
            ZStack(
                alignment: .bottom,
            ) {
                TabView(
                    selection: Binding(
                        get: {
                            viewModel.state.selectedPhotoID
                        },
                        set: viewModel.onPhotoSelected,
                    ),
                ) {
                    ForEach(
                        viewModel.state.photos,
                    ) { photo in
                        PhotoViewZoomableImage(
                            photoId: photo.id,
                            image: photo.image,
                            isSelected: photo.id == viewModel.state.selectedPhotoID,
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

                if !viewModel.state.photos.isEmpty {
                    PhotoViewControlsView()
                        .padding(
                            size.s16,
                        )
                        .onGeometryChange(
                            for: CGFloat.self,
                            of: {
                                $0.size.height
                            },
                        ) { height in
                            controlsHeight = height
                        }
                }
            }
        }
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
    }
}
