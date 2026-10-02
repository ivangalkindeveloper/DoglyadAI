struct DExaminationProposalGenerationResponse: Codable {
    let proposals: [DExaminationProposalGenerationItem]
    let unmappedFindings: [String]

    @available(iOS 26.0, *)
    static func fromFoundationModels(_ response: DExaminationProposalFoundationResponse) throws -> Self {
        let proposals = try response.proposals.map { item in
            guard let fieldId = VoiceFieldId(rawValue: item.fieldId) else {
                throw DictationProposalError.unknownField
            }
            return DExaminationProposalGenerationItem(
                fieldId: fieldId,
                value: item.value,
                sourceQuote: item.sourceQuote
            )
        }
        return Self(proposals: proposals, unmappedFindings: response.unmappedFindings)
    }
}
