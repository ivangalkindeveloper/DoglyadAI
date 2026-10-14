import SwiftUI
internal import Shimmer
internal import SwiftMessages

public extension View {
    @ViewBuilder func `if`(
        _ isConditionSatisfied: Bool,
        transform: (Self) -> some View,
    ) -> some View {
        if isConditionSatisfied {
            transform(
                self,
            )
        } else {
            self
        }
    }

    @ViewBuilder func ifLet<T>(
        _ value: T?,
        transform: (Self, T) -> some View,
    ) -> some View {
        if let value {
            transform(
                self,
                value,
            )
        } else {
            self
        }
    }

    @ViewBuilder func ifLetElse<T, Content: View>(
        _ value: T?,
        transform: (Self, T) -> Content,
        else: (Self) -> Content,
    ) -> some View {
        if let value {
            transform(
                self,
                value,
            )
        } else {
            `else`(
                self,
            )
        }
    }

    func dThemeWrapper() -> some View {
        modifier(
            DThemeWrapperModifier(),
        )
    }

    func dMessage() -> some View {
        modifier(
            DMessageModifier(),
        )
    }

    func dShimmer(
        isShimmering: Bool = true,
        cornerRadius: CGFloat = .infinity,
    ) -> some View {
        modifier(
            DShimmerModifier(
                isShimmering: isShimmering,
                cornerRadius: cornerRadius,
            ),
        )
    }
}
