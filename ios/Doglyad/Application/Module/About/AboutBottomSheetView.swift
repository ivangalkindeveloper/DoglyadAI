import DoglyadUI
import SwiftUI

struct AboutBottomSheetView: View {
    @Environment(\.locale) private var locale: Locale
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: AboutViewModel

    var body: some View {
        DBottomSheet(
            title: .settingsAboutAppTitle,
            fraction: 0.6
        ) { toolbarHeight, bottomHeight in
            VStack(
                spacing: .zero
            ) {
                Image(.doglyadAbout)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )

                DText(.aboutDescription)
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleHeader,
                        alignment: .center
                    )
                    .padding(.bottom, size.s16)

                DText("\(localizedResource(.aboutVersion)): \(viewModel.version)")
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscalePlacehold,
                        alignment: .center
                    )
            }
            .padding(size.s16)
            .padding(.top, toolbarHeight)
            .padding(.bottom, bottomHeight)
        } bottom: {
            Text(contactAttributedText())
                .multilineTextAlignment(.center)
                .tint(color.primaryDefault)
                .padding(size.s16)
                .environment(\.openURL, OpenURLAction { _ in
                    viewModel.onTapEmail()
                    return .systemAction
                })
        }
        .onAppear(perform: viewModel.onAppear)
    }

    private func contactAttributedText() -> AttributedString {
        var description = AttributedString(localizedResource(.aboutContactDescription))
        description.font = typography.textSmall
        description.foregroundColor = color.grayscaleHeader

        var email = AttributedString(viewModel.contactEmail)
        email.font = typography.textSmall
        email.foregroundColor = color.primaryDefault
        email.link = URL(string: "mailto:\(email)")

        return description + " " + email
    }

    private func localizedResource(
        _ resource: LocalizedStringResource
    ) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }
}
