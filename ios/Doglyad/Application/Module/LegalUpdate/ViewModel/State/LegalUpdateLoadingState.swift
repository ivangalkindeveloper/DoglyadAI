import Foundation

@MainActor
final class LegalUpdateLoadingState: LegalUpdateStateProtocol, @MainActor Equatable {
    static func == (
        _: LegalUpdateLoadingState,
        _: LegalUpdateLoadingState,
    ) -> Bool {
        true
    }
}
