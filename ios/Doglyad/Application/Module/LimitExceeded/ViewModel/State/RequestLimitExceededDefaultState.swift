@MainActor
final class RequestLimitExceededDefaultState: RequestLimitExceededStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: RequestLimitExceededDefaultState,
        _: RequestLimitExceededDefaultState,
    ) -> Bool {
        true
    }
}
