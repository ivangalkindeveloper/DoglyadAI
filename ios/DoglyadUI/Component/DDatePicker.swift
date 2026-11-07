import SwiftUI

public struct DDatePicker: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let title: LocalizedStringResource
    private let range: ClosedRange<Date>
    @Binding private var selection: Date
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        _ title: LocalizedStringResource,
        selection: Binding<Date>,
        in range: ClosedRange<Date>,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.title = title
        self.range = range
        _selection = selection
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            DatePicker(
                title,
                selection: $selection,
                in: range,
                displayedComponents: [.date],
            )
            .labelsHidden()
            .datePickerStyle(
                .wheel,
            )
            .colorScheme(
                .light,
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
