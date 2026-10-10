@frozen public enum DNeuralDictationProposalSource: Sendable {
    case labeledDictation
    case explicitFacts
    case localModel
    case serverModel
}
