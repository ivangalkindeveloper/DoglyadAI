struct DExaminationProposalGenerationResponse: Codable {
    let proposals: [DExaminationProposalGenerationItem]
    let unmappedFindings: [String]

    @available(iOS 26.0, *)
    static func fromFoundationModels(_ response: [DExaminationProposalFoundationItem]) -> Self {
        var proposals: [DExaminationProposalGenerationItem] = []
        var unmappedFindings: [String] = []
        for item in response {
            guard let fieldId = VoiceFieldId(wireValue: item.field_id) else {
                unmappedFindings.append(item.evidence)
                continue
            }
            proposals.append(DExaminationProposalGenerationItem(
                fieldId: fieldId,
                value: item.value,
                sourceQuote: item.evidence,
                accuracy: VoiceFieldAccuracy(rawValue: item.accuracy) ?? .questionable
            ))
        }
        return Self(proposals: proposals, unmappedFindings: unmappedFindings)
    }
}
