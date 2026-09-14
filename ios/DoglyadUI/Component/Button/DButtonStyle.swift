import SwiftUI

public enum DButtonStyleType {
    case primaryButton
    case primaryCircle
    case primaryChip
    case primaryText
    case circle
    case card
    case chip
    case textWeak
}

public struct DButtonStyle: ButtonStyle {
    @EnvironmentObject private var theme: DTheme
    @Environment(\.isEnabled) private var isEnabled
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }

    let type: DButtonStyleType
    let customBackgroundColor: Color?

    public init(
        _ type: DButtonStyleType,
        backgroundColor: Color? = nil
    ) {
        self.type = type
        customBackgroundColor = backgroundColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(size.s14)
            .frame(
                width: width
            )
            .frame(
                maxWidth: maxWidth,
                minHeight: size.s48
            )
            .progressViewStyle(
                CircularProgressViewStyle(tint: currentForegroundColor)
            )
            .foregroundColor(currentForegroundColor)
            .foregroundStyle(currentForegroundColor)
            .background(currentBackground)
            .opacity(
                configuration.isPressed ? 0.6 : 1
            )
            .animation(
                .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}

private extension DButtonStyle {
    static let defaultGradient: LinearGradient = .init(colors: [], startPoint: .top, endPoint: .top)
    static let defaultColor: Color = .clear

    var backgroundGradient: LinearGradient {
        switch type {
        case .primaryButton, .primaryCircle, .primaryChip:
            return color.gradientPrimaryWeak
        case .primaryText, .circle, .card, .chip, .textWeak:
            return Self.defaultGradient
        }
    }

    var backgroundColor: Color {
        if let customBackgroundColor {
            return customBackgroundColor
        }

        switch type {
        case .primaryButton, .primaryCircle, .primaryChip, .primaryText, .textWeak:
            return Self.defaultColor
        case .circle, .card, .chip:
            return color.grayscaleBackground
        }
    }

    var foregroundColor: Color {
        switch type {
        case .primaryButton, .primaryCircle, .primaryChip:
            return color.grayscaleBackground
        case .circle, .card, .chip:
            return color.grayscaleHeader
        case .primaryText:
            return color.primaryDefault
        case .textWeak:
            return color.grayscaleBackgroundWeak
        }
    }

    var currentForegroundColor: Color {
        isEnabled ? foregroundColor : color.grayscalePlacehold
    }

    @ViewBuilder
    var currentBackground: some View {
        if isEnabled {
            enabledBackground
        } else {
            disabledBackground
        }
    }

    @ViewBuilder
    var enabledBackground: some View {
        let cornerRadius = self.cornerRadius ?? size.s16
        switch type {
        case .primaryButton:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundGradient)
        case .primaryCircle:
            Circle()
                .fill(backgroundGradient)
        case .primaryChip:
            Capsule()
                .fill(backgroundGradient)
        case .circle:
            Circle()
                .fill(backgroundColor)
        case .card:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
        case .chip:
            Capsule()
                .fill(backgroundColor)
        case .primaryText, .textWeak:
            Color.clear
        }
    }

    @ViewBuilder
    var disabledBackground: some View {
        let cornerRadius = self.cornerRadius ?? size.s16
        switch type {
        case .primaryButton:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color.grayscaleInput)
        case .primaryCircle:
            Circle()
                .fill(color.grayscaleInput)
        case .primaryChip:
            Capsule()
                .fill(color.grayscaleInput)
        case .circle:
            Circle()
                .fill(color.grayscaleInput)
        case .card:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color.grayscaleInput)
        case .chip:
            Capsule()
                .fill(color.grayscaleInput)
        case .primaryText, .textWeak:
            Color.clear
        }
    }

    var cornerRadius: CGFloat? {
        switch type {
        case .primaryButton:
            return size.adaptiveCornerRadius
        case .card:
            return size.adaptiveCardCornerRadius
        case .primaryCircle, .primaryChip, .primaryText, .circle, .chip, .textWeak:
            return nil
        }
    }

    var width: CGFloat? {
        switch type {
        case .primaryButton, .primaryChip, .primaryText, .card, .chip, .textWeak:
            return nil
        case .primaryCircle, .circle:
            return size.s56
        }
    }

    var maxWidth: CGFloat? {
        switch type {
        case .primaryButton, .primaryText, .card, .textWeak:
            return .infinity
        case .primaryCircle, .primaryChip, .circle, .chip:
            return nil
        }
    }
}
