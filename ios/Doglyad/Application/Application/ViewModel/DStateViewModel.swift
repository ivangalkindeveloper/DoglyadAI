import Combine
import DoglyadNetwork
import Handler
import SwiftUI

/// The root and module models share publication without sharing module dependencies.
@MainActor
class DStateViewModel<State>: Handler<DHttpApiError, DHttpConnectionError>, ObservableObject {
    @Published private(set) var state: State

    init(
        state: State,
    ) {
        self.state = state
        super.init()
    }

    final func emit(
        _ newState: State,
        animation: Animation? = .easeInOut(
            duration: 0.35,
        ),
    ) {
        if let currentState = state as? any Equatable,
           currentState.isEqual(
               to: newState,
           )
        {
            return
        }

        withAnimation(
            animation,
        ) {
            state = newState
        }
    }
}
