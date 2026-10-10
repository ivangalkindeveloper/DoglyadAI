import SwiftUI

public struct DText: View {
    private let text: Text

    public init(
        _ localized: LocalizedStringResource,
    ) {
        text = Text(
            localized,
        )
    }

    public init(
        _ string: String,
    ) {
        text = Text(
            verbatim: string,
        )
    }

    public init(
        _ attributed: AttributedString,
    ) {
        text = Text(
            attributed,
        )
    }

    public var body: some View {
        text
    }
}

public extension DText {
    func dStyle(
        font: Font? = nil,
        color: Color? = nil,
        alignment: TextAlignment? = nil,
    ) -> some View {
        modifier(
            DTextModifier(
                font: font,
                color: color,
                alignment: alignment,
            ),
        )
    }
}

private struct DTextModifier: ViewModifier {
    @EnvironmentObject private var theme: DTheme
    private var typography: DTypography { theme.typography }

    let font: Font?
    let color: Color?
    let alignment: TextAlignment?

    init(
        font: Font?,
        color: Color?,
        alignment: TextAlignment?,
    ) {
        self.font = font
        self.color = color
        self.alignment = alignment
    }

    func body(
        content: Content,
    ) -> some View {
        content
            .font(
                font ?? typography.textMedium,
            )
            .foregroundStyle(
                color ?? theme.color.grayscaleHeader,
            )
            .multilineTextAlignment(
                alignment ?? .leading,
            )
    }
}

#Preview {
    DText(
        "Hello, World!",
    )
    .dThemeWrapper()
}
