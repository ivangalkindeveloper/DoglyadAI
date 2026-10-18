import Foundation

@MainActor
final class ReportDetailGeneratingState: ReportDetailStateProtocol, @MainActor Equatable {
    static func == (
        _: ReportDetailGeneratingState,
        _: ReportDetailGeneratingState,
    ) -> Bool {
        true
    }
}
