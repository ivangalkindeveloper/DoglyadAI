import Foundation

@MainActor
final class SelectTranscriberInitialState: SelectTranscriberStateProtocol, @MainActor Equatable {
    let options: [TranscriberType]

    init(
        options: [TranscriberType] = [.whisperKit],
    ) {
        self.options = options
    }

    func copyWith(
        options: [TranscriberType]? = nil,
    ) -> SelectTranscriberInitialState {
        SelectTranscriberInitialState(
            options: options ?? self.options,
        )
    }

    static func == (
        lhs: SelectTranscriberInitialState,
        rhs: SelectTranscriberInitialState,
    ) -> Bool {
        lhs.options == rhs.options
    }
}
