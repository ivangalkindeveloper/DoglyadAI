import SwiftUI

struct DAccessibilityModifier: ViewModifier {
    let element: AccessibilityChildBehavior?
    let identifier: String?
    var traits: AccessibilityTraits?

    func body(
        content: Content,
    ) -> some View {
        content
            .ifLet(
                element,
            ) { view, behavior in
                view.accessibilityElement(
                    children: behavior,
                )
            }
            .ifLet(
                identifier,
            ) { view, identifier in
                view.accessibilityIdentifier(
                    identifier,
                )
            }
            .ifLet(
                traits,
            ) { view, traits in
                view.accessibilityAddTraits(
                    traits,
                )
            }
    }
}
