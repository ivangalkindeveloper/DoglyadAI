import DoglyadUI
import SwiftUI

struct AboutBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.locale,
    ) private var locale: Locale
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: AboutViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .settingsAboutAppButton,
            ],
            fraction: 0.6,
        ) { toolbarHeight, bottomHeight in
            VStack(
                spacing: .zero,
            ) {
                DImage(
                    .doglyadAbout,
                )
                .scaledToFit()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center,
                )

                DText(
                    l10n[
                        .aboutDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleHeader,
                    alignment: .center,
                )
                .padding(
                    .bottom,
                    size.s8,
                )

                DText(
                    viewModel.versionDescription,
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscalePlacehold,
                    alignment: .center,
                )
            }
            .padding(
                size.s16,
            )
            .padding(
                .top,
                toolbarHeight,
            )
            .padding(
                .bottom,
                bottomHeight,
            )
        } bottom: {
            DText(
                viewModel.contactAttributedText(
                    theme: theme,
                ),
            )
            .multilineTextAlignment(
                .center,
            )
            .tint(
                color.primaryDefault,
            )
            .padding(
                size.s16,
            )
            .environment(
                \.openURL,
                OpenURLAction { _ in
                    viewModel.onTapEmail()
                    return .systemAction
                },
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
