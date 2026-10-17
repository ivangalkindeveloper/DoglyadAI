import DoglyadUI
import SwiftUI

struct ErrorView<Description: View>: DViewProtocol {
    @EnvironmentObject private var applicationViewModel: ApplicationRootViewModel
    @EnvironmentObject var theme: DTheme

    private let title: LocalizedStringResource
    private let buttonTitle: LocalizedStringResource?
    private let action: (() -> Void)?
    private let description: () -> Description

    init(
        title: LocalizedStringResource,
        buttonTitle: LocalizedStringResource? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder description: @escaping () -> Description,
    ) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.action = action
        self.description = description
    }

    var body: some View {
        let isInitializing = switch applicationViewModel.state {
        case _ as ApplicationRootInitializingState: true
        default: false
        }
        DScreen { _, bottomInset in
            ErrorInitializationView(
                title: title,
                description: description,
            ).padding(
                .bottom,
                bottomInset,
            )
        } bottom: {
            switch (buttonTitle, action) {
            case let (.some(
                title,
            ), .some(
                action,
            )):
                DButton(
                    title: title,
                    action: action,
                    isLoading: isInitializing,
                ).dStyle(
                    .primaryButton,
                ).padding(
                    size.s16,
                )
            default: EmptyView()
            }
        }
    }
}
