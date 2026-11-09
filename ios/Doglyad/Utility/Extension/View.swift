import SwiftUI

extension View {
    #if DEBUG
        func previewScrollToEnd() -> some View {
            defaultScrollAnchor(
                .bottomLeading,
                for: .initialOffset,
            )
            .overlay(
                alignment: .topLeading,
            ) {
                PreviewScrollEndView()
                    .frame(
                        width: 1,
                        height: 1,
                    )
                    .allowsHitTesting(
                        false,
                    )
            }
            .environment(
                \.isPreviewScrollEnd,
                true,
            )
        }

        func previewError(
            isPresented: Bool,
            description: String? = nil,
        ) -> some View {
            modifier(
                PreviewErrorModifier(
                    isPresented: isPresented,
                    description: description,
                ),
            )
        }
    #endif

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

    func paidBadge(
        _ availability: SubscriptionFeatureAvailability,
    ) -> some View {
        modifier(
            PaidBadgeModifier(
                availability: availability,
            ),
        )
    }

    func previewable(
        container: DependencyContainer? = nil,
        router: DRouter? = nil,
    ) -> some View {
        modifier(
            PreviewableModifier(
                container: container,
                router: router,
            ),
        )
    }
}
