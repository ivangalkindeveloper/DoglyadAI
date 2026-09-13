import SwiftUI

public struct DSegmentItem<T: Equatable>: Identifiable {
    public let id: UUID = .init()
    let value: T
    let title: LocalizedStringResource
    let action: () -> Void

    public init(
        value: T,
        title: LocalizedStringResource,
        action: @escaping () -> Void
    ) {
        self.value = value
        self.title = title
        self.action = action
    }
}

public struct DSegment<T: Equatable>: DView {
    @EnvironmentObject public var theme: DTheme

    let currentValue: T?
    let items: [DSegmentItem<T>]

    public init(
        currentValue: T?,
        items: [DSegmentItem<T>]
    ) {
        self.currentValue = currentValue
        self.items = items
    }

    public var body: some View {
        HStack(
            spacing: size.s8
        ) {
            ForEach(items) { item in
                Button(
                    action: item.action
                ) {
                    Text(item.title)
                        .font(typography.linkSmall)
                }
                .buttonStyle(
                    DSegmentButtonStyle(
                        currentValue == item.value
                    )
                )
            }
        }
        .animation(
            .easeOut(duration: 0.1),
            value: currentValue
        )
    }
}

public struct DSegmentButtonStyle: ButtonStyle {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    let condition: Bool

    public init(
        _ condition: Bool
    ) {
        self.condition = condition
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(size.s8)
            .frame(maxWidth: .infinity)
            .background(background)
            .foregroundColor(foregroundColor)
            .foregroundStyle(foregroundColor)
            .opacity(
                configuration.isPressed ? 0.6 : 1
            )
            .animation(
                .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }

    @ViewBuilder
    var background: some View {
        if condition {
            Capsule()
                .fill(color.gradientPrimaryWeak)
        } else {
            Capsule()
                .fill(color.grayscaleBackground)
        }
    }

    var foregroundColor: Color {
        condition ? color.grayscaleBackground : color.grayscaleHeader
    }
}

#Preview {
    @Previewable @State var value = ""

    DScreen { _, _ in
        DSegment<String>(
            currentValue: value,
            items: [
                DSegmentItem<String>(value: "Apple", title: "Value - Apple", action: {
                    value = "Apple"
                }),
                DSegmentItem<String>(value: "Cherry", title: "Value - Cherry", action: {
                    value = "Cherry"
                }),
            ]
        )
        .redacted(reason: .placeholder)
        .padding()
    }
    .dThemeWrapper()
}
