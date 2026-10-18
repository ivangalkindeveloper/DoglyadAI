@MainActor
final class RequestLimitExceededState: RequestLimitExceededStateProtocol, @MainActor Equatable {
    static func == (
        _: RequestLimitExceededState,
        _: RequestLimitExceededState,
    ) -> Bool {
        true
    }
}
