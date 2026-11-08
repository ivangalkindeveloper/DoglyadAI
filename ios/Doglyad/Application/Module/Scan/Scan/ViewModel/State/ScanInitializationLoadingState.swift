import Foundation

@MainActor
final class ScanInitializationLoadingState: ScanStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanInitializationLoadingState,
        _: ScanInitializationLoadingState,
    ) -> Bool {
        true
    }
}
