public enum DictationProposalError: Error {
    case fieldNotAllowed(VoiceFieldId)
    case duplicateField(VoiceFieldId)
    case invalidValue(VoiceFieldId)
}
