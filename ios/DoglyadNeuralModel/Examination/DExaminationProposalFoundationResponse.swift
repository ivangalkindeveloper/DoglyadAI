import FoundationModels

@available(iOS 26.0, *)
@FoundationModels.Generable
struct DExaminationProposalFoundationResponse {
    let proposals: [DExaminationProposalFoundationItem]
    let unmappedFindings: [String]
}
