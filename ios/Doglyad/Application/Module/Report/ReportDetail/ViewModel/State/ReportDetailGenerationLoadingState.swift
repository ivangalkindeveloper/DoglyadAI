import Foundation

@MainActor
final class ReportDetailGenerationLoadingState: ReportDetailStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ReportDetailGenerationLoadingState,
        _: ReportDetailGenerationLoadingState,
    ) -> Bool {
        true
    }
}
