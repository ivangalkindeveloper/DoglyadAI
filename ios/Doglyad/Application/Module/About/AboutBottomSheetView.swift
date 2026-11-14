import DoglyadUI
import SwiftUI

struct AboutBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.locale,
    ) private var locale: Locale
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: AboutViewModel

    init(
        viewModel: @autoclosure @escaping () -> AboutViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DBottomSheet(
            title: l10n[
                .menuAboutAppButton,
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
                    width: size.screenWidth / 3,
                    height: size.screenWidth / 3,
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
                OpenURLAction { url in
                    viewModel.onTapEmail()
                    #if DEBUG && DOGLYAD_REGRESSION
                        if RegressionExternalActions.handle(
                            url,
                        ) {
                            return .handled
                        }
                    #endif
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
