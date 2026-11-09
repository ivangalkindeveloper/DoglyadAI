import DoglyadUI
import SwiftUI

struct PaywallFooterLinkButton: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let title: LocalizedStringResource
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        DTextButton(
            action: action,
            content: {
                DText(
                    title,
                )
                .dStyle(
                    font: typography.linkXSmall,
                    color: color.primaryDefault,
                    alignment: .center,
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true,
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: size.s48,
                    alignment: .top,
                )
                .contentShape(
                    Rectangle(),
                )
            },
            isDisabled: isDisabled,
        )
    }
}
