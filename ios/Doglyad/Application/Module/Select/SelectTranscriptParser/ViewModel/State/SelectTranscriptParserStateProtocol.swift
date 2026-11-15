import Foundation

@MainActor
protocol SelectTranscriptParserStateProtocol: AnyObject {
    var isFoundationModelsAvailable: Bool {
        get
    }

    func copyWith(
        isFoundationModelsAvailable: Bool?,
    ) -> SelectTranscriptParserDefaultState
}
