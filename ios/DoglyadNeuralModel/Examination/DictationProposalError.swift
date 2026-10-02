public enum DictationProposalError: Error {
    case unknownField
    case fieldNotAllowed(VoiceFieldId)
    case duplicateField(VoiceFieldId)
    case invalidValue(VoiceFieldId)
}
