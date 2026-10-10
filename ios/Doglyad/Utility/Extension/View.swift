import SwiftUI

extension View {
    /// Supplies the catalog and the matching locale to the whole view hierarchy.
    func localization(
        _ l10n: L10N,
    ) -> some View {
        environmentObject(
            l10n,
        )
        .environment(
            \.locale,
            l10n.locale,
        )
    }
}
