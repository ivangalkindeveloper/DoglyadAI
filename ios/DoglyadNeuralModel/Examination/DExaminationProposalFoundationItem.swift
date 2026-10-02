import FoundationModels

@available(iOS 26.0, *)
@FoundationModels.Generable
struct DExaminationProposalFoundationItem {
    @FoundationModels.Guide(description: "One of: examinationNumber, patientName, patientGender, patientDateOfBirth, patientHeightCM, patientWeightKG, patientComplaints, examinationDescription")
    let fieldId: String

    @FoundationModels.Guide(description: "The proposed value as text. Preserve leading zeros in examinationNumber.")
    let value: String

    @FoundationModels.Guide(description: "An exact contiguous quote copied from the dictation, with no changed characters")
    let sourceQuote: String
}
