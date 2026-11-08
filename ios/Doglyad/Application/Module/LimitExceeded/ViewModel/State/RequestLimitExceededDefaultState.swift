@MainActor
final class RequestLimitExceededDefaultState: RequestLimitExceededStateProtocol, @MainActor Equatable {
    static func == (
        _: RequestLimitExceededDefaultState,
        _: RequestLimitExceededDefaultState,
    ) -> Bool {
        true
    }
}
