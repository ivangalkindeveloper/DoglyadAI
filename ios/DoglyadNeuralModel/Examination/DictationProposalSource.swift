@frozen public enum DictationProposalSource: Sendable {
    case labeledDictation
    case explicitFacts
    case localModel
    case serverModel
}
