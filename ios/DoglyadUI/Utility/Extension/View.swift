import SwiftUI

public extension View {
    @ViewBuilder func `if`(
        _ condition: Bool,
        transform: (Self) -> some View,
    ) -> some View {
        if condition {
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
}
