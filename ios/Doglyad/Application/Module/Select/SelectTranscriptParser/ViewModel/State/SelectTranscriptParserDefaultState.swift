@MainActor
final class SelectTranscriptParserDefaultState: SelectTranscriptParserStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SelectTranscriptParserDefaultState,
        _: SelectTranscriptParserDefaultState,
    ) -> Bool {
        true
    }
}
