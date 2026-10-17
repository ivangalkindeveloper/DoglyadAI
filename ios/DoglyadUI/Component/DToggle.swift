import SwiftUI

public struct DToggle: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let title: LocalizedStringResource
    @Binding private var isOn: Bool

    public init(
        _ title: LocalizedStringResource,
        isOn: Binding<Bool>,
    ) {
        self.title = title
        _isOn = isOn
    }

    public var body: some View {
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
}
