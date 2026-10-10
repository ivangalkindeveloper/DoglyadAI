public enum DNeuralUltrasoundDictationProposalError: Error {
    case fieldNotAllowed(DNeuralUltrasoundVoiceFieldId)
    case duplicateField(DNeuralUltrasoundVoiceFieldId)
    case invalidValue(DNeuralUltrasoundVoiceFieldId)
}
