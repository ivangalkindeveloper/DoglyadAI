@MainActor
final class SelectTranscriptParserDefaultState: SelectTranscriptParserStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTranscriptParserDefaultState,
        _: SelectTranscriptParserDefaultState,
    ) -> Bool {
        true
    }
}
