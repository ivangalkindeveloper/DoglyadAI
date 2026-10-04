import FoundationModels

@available(iOS 26.0, *)
@FoundationModels.Generable
struct DExaminationProposalFoundationItem {
    @FoundationModels.Guide(description: "One of: examination_number, patient_name, patient_gender, patient_date_of_birth, patient_height_cm, patient_weight_kg, patient_complaints, examination_description")
    let field_id: String

    @FoundationModels.Guide(description: "The proposed value as text. Preserve leading zeros in examination_number.")
    let value: String

    @FoundationModels.Guide(description: "An exact contiguous quote copied from the dictation, with no changed characters")
    let evidence: String

    @FoundationModels.Guide(description: "full only if this field and value are unambiguous in the dictation; otherwise questionable")
    let accuracy: String
}
