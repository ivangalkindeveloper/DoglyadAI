import Foundation

@MainActor
final class ReportDetailContentState: ReportDetailStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ReportDetailContentState,
        _: ReportDetailContentState,
    ) -> Bool {
        true
    }
}
