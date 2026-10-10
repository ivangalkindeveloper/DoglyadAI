@frozen public enum DNeuralVoiceProposalWarning: String, Hashable, Sendable {
    case ambiguousDictation
    case sideMismatch
    case negationMismatch
    case numberMismatch
    case unitMismatch
    case dateUnverified
    case genderUnverified
    case identifierMismatch
    case textChanged
}
