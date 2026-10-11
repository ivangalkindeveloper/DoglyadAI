import SwiftUI

public struct DDatePicker: DView {
    @EnvironmentObject public var theme: DTheme
    private let title: LocalizedStringResource
    private let range: ClosedRange<Date>
    @Binding private var selection: Date

    public init(
        _ title: LocalizedStringResource,
        selection: Binding<Date>,
        in range: ClosedRange<Date>,
    ) {
        self.title = title
        self.range = range
        _selection = selection
    }

    public var body: some View {
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
}
