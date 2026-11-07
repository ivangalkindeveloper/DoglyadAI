import SwiftUI

public struct DToggle: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let title: LocalizedStringResource
    @Binding private var isOn: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        _ title: LocalizedStringResource,
        isOn: Binding<Bool>,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.title = title
        _isOn = isOn
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            Toggle(
                title,
                isOn: $isOn,
            )
            .toggleStyle(
                .switch,
            )
            .tint(
                color.primaryDefault,
            )
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}
