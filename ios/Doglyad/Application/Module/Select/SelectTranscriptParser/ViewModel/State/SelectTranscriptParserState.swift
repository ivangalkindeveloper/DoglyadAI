@MainActor
final class SelectTranscriptParserState: SelectTranscriptParserStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTranscriptParserState,
        _: SelectTranscriptParserState,
    ) -> Bool { true }
}
