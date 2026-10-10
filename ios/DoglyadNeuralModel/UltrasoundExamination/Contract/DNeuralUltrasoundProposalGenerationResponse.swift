struct DNeuralUltrasoundProposalGenerationResponse: Codable, Sendable {
    let proposals: [DNeuralUltrasoundProposalGenerationItem]
    let unmappedFindings: [String]
}
