import Foundation

@MainActor
final class SelectTranscriptParserDefaultState: SelectTranscriptParserStateProtocol, @MainActor Equatable {
    let isFoundationModelsAvailable: Bool

    init(
        isFoundationModelsAvailable: Bool = false,
    ) {
        self.isFoundationModelsAvailable = isFoundationModelsAvailable
    }

    func copyWith(
        isFoundationModelsAvailable: Bool? = nil,
    ) -> SelectTranscriptParserDefaultState {
        SelectTranscriptParserDefaultState(
            isFoundationModelsAvailable: isFoundationModelsAvailable ?? self.isFoundationModelsAvailable,
        )
    }

    static func == (
        lhs: SelectTranscriptParserDefaultState,
        rhs: SelectTranscriptParserDefaultState,
    ) -> Bool {
        lhs.isFoundationModelsAvailable == rhs.isFoundationModelsAvailable
    }
}
