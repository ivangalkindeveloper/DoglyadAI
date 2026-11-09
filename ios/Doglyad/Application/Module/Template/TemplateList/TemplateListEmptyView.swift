import DoglyadUI
import SwiftUI

struct TemplateListEmptyView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    var body: some View {
        EmptyTemplatesBodyView(
            description: l10n[
                .templateListEmptyDescription,
            ],
        )
        .padding(
            .top,
            size.screenHeight / 6,
        )
    }
}
