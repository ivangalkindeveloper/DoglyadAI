import Foundation

@MainActor
protocol SelectTranscriberStateProtocol: AnyObject {
    var options: [TranscriberType] {
        get
    }

    func copyWith(
        options: [TranscriberType]?,
    ) -> SelectTranscriberInitialState
}
