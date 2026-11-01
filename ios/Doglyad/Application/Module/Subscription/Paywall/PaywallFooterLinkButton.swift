import DoglyadUI
import SwiftUI

struct PaywallFooterLinkButton: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        DButtonCard(
            isPlain: true,
            action: action,
        ) {
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
        }
    }
}
