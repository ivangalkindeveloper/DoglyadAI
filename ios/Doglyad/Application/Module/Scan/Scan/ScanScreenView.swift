import DoglyadUI
import SwiftUI

struct ScanScreenView: View {
    @EnvironmentObject private var theme: DTheme
    private var size: DSize { theme.size }

    @StateObject var viewModel: ScanViewModel
    @FocusState private var focus: ScanViewModel.Focus?

    var body: some View {
        DScreen(
            toolbarType: .blur,
            leading: {
                DButton(
                    image: .hambergerMenu,
                    action: viewModel.onTapSettings
                )
                .dStyle(.circle)
            },
            titleContent: {
                DButton(
                    image: .down,
                    title: viewModel.usExaminationType.getLocalizedTitle(for: Locale.current),
                    action: viewModel.onTapUSExaminationType
                )
                .dStyle(.primaryChip)
            },
            onTapBody: viewModel.unfocus,
            content: { toolbarHeight, _ in
                ZStack(
                    alignment: .bottom
                ) {
                    ScrollView(
                        showsIndicators: false
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: .zero
                        ) {
                            if !viewModel.isPhotoFilling {
                                HStack(
                                    spacing: size.s8
                                ) {
                                    ScanMediaButtonView(
                                        image: .camera,
                                        title: .buttonCamera,
                                        action: viewModel.onTapCamera
                                    )

                                    ScanMediaButtonView(
                                        image: .image,
                                        title: .buttonGallery,
                                        action: viewModel.onTapGallery
                                    )
                                }
                                .padding(.horizontal, size.s16)
                                .padding(.bottom, size.s8)
                            }

                            ScanPhotosView(
                                photos: viewModel.photos,
                                photoMaxCount: viewModel.photoMaxCount,
                                onTapDelete: viewModel.onTapDeletePhoto
                            )

                            ScanFormView(
                                focus: $focus
                            )
                        }
                        .padding(.top, toolbarHeight + size.s16)
                        .padding(.bottom, size.s136)
                    }

                    ScanBottomView()
                }
            }
        )
        .ignoresSafeArea(.keyboard)
        .onSubmit {
            viewModel.onSubmit()
        }
        .onChange(of: focus, initial: true) { _, newValue in
            guard viewModel.focus != newValue else { return }
            viewModel.focus = newValue
        }
        .onChange(of: viewModel.focus, initial: true) { _, newValue in
            guard focus != newValue else { return }
            focus = newValue
        }
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
