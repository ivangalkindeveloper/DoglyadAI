import DoglyadUI
import SwiftUI

struct ScanScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ScanViewModel
    @FocusState private var focus: ScanViewModel.Focus?

    var body: some View {
        DScreen(
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
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        upAccessibilityLabel: .buttonBack,
                        downAccessibilityLabel: .buttonNext,
                        doneAccessibilityLabel: .buttonDone,
                        onTapUp: viewModel.canFocusPreviousField ? { viewModel.onTapToolbarUp() } : nil,
                        onTapDown: viewModel.canFocusNextField ? { viewModel.onTapToolbarDown() } : nil,
                        onTapDone: viewModel.unfocus
                    )
                }
            },
            content: { toolbarHeight, _ in
                ZStack(
                    alignment: .bottom
                ) {
                    DFocusScrollView(
                        focus: focus
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

                            ScanPhotoListView()

                            ScanFormView(
                                focus: $focus
                            )
                        }
                        .padding(.top, toolbarHeight + size.s16)
                        .padding(.bottom, size.s136 * 2)
                    }

                    ScanBottomView()
                }
            }
        )
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
