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

        animate(
            animation: animation,
        ) {
            state = newState
            // SwiftUI can render synchronously from Published.willSet while flushing
            // nested controller updates. Invalidate again with the assigned phase so
            // those views cannot retain the previous loading/disabled state.
            objectWillChange.send()
        }
    }

    final func animate(
        animation: Animation? = .easeInOut(
            duration: 0.35,
        ),
        _ updates: () -> Void,
    ) {
        withAnimation(
            animation,
            updates,
        )
    }
}
