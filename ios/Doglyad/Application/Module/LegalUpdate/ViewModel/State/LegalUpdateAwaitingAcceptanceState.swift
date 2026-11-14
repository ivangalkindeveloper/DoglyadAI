import Foundation

@MainActor
final class LegalUpdateAwaitingAcceptanceState: LegalUpdateStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: LegalUpdateAwaitingAcceptanceState,
        _: LegalUpdateAwaitingAcceptanceState,
    ) -> Bool {
        true
    }
}
