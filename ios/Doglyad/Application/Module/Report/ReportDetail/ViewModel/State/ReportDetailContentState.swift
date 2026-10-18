import Foundation

@MainActor
final class ReportDetailContentState: ReportDetailStateProtocol, @MainActor Equatable {
    static func == (
        _: ReportDetailContentState,
        _: ReportDetailContentState,
    ) -> Bool {
        true
    }
}
