import DoglyadUI
import SwiftUI

struct PhotoRemarkBottomSheetView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @StateObject var viewModel: PhotoRemarkViewModel

    var body: some View {
        DBottomSheet(
            type: .blur,
            title: l10n[
                .photoRemarkTitle,
            ],
            fraction: 0.45,
        ) { toolbarHeight, bottomHeight in
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: size.s16,
                ) {
                    DText(
                        viewModel.title,
                    )
                    .dStyle(
                        font: typography.displaySmallBold,
                        color: color.grayscaleBackground,
                    )
                    DMarkdown(
                        content: viewModel.description,
                        textColor: color.grayscaleBackgroundWeak,
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                .padding(
                    .top,
                    toolbarHeight,
                )
                .padding(
                    size.s16,
                )
                .padding(
                    .bottom,
                    bottomHeight,
                )
            }
        } bottom: {
            DButton(
                title: l10n[
                    .buttonBack,
                ],
                action: viewModel.onTapBack,
            )
            .dStyle(
                .primaryButton,
            )
            .padding(
                .horizontal,
                size.s16,
            )
        }
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
