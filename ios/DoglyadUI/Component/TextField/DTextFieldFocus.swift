import SwiftUI

public final class DTextFieldFocus<Focus: Hashable> {
    public let value: Focus
    public let state: FocusState<Focus?>.Binding

    public init(
        value: Focus,
        state: FocusState<Focus?>.Binding
    ) {
        self.value = value
        self.state = state
    }

    public var isFocused: Bool {
        state.wrappedValue == value
    }
}
