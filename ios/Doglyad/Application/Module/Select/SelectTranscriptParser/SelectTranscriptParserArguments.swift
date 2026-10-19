import Router

final class SelectTranscriptParserArguments: RouteArgumentsProtocol {
    let currentValue: TranscriptParserType
    let onSelected: (TranscriptParserType) -> Void

    init(
        currentValue: TranscriptParserType,
        onSelected: @escaping (TranscriptParserType) -> Void,
    ) {
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
