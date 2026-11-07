#if DEBUG
    import DoglyadUI
    import SwiftUI

    struct PreviewErrorModifier: ViewModifier {
        @EnvironmentObject private var messager: DMessager
        @EnvironmentObject private var container: DependencyContainer
        let isPresented: Bool

        func body(
            content: Content,
        ) -> some View {
            content
                .task(
                    id: isPresented,
                ) {
                    guard isPresented else {
                        return
                    }
                    // Let the real bottom sheet finish presenting before the banner.
                    do {
                        try await Task.sleep(
                            for: .seconds(
                                1,
                            ),
                        )
                    } catch {
                        return
                    }
                    messager.showUnknownError(
                        l10n: container.l10n,
                    )
                }
        }
    }
#endif
