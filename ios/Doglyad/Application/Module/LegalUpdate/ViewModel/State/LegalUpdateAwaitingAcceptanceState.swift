import Foundation

@MainActor
final class LegalUpdateAwaitingAcceptanceState: LegalUpdateStateProtocol, @MainActor Equatable {
    static func == (
        _: LegalUpdateAwaitingAcceptanceState,
        _: LegalUpdateAwaitingAcceptanceState,
    ) -> Bool {
        true
    }
}
