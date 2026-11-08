import Foundation

@MainActor
final class ReportDetailGenerationLoadingState: ReportDetailStateProtocol, @MainActor Equatable {
    static func == (
        _: ReportDetailGenerationLoadingState,
        _: ReportDetailGenerationLoadingState,
    ) -> Bool {
        true
    }
}
