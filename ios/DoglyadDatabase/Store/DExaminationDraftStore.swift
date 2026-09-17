import Foundation
import SwiftData

@ModelActor
public actor DExaminationDraftStore {
    public func fetchDraft<T: Sendable>(
        _ transform: @Sendable (USExaminationDraftDB?) -> T
    ) -> T {
        transform(fetchDraft())
    }

    public func upsertDraftForm(
        value: USExaminationDraftDB
    ) throws {
        if let draft = fetchDraft() {
            draft.examinationNumber = value.examinationNumber
            draft.patientName = value.patientName
            draft.patientGenderRawValue = value.patientGenderRawValue
            draft.patientDateOfBirth = value.patientDateOfBirth
            draft.patientHeightCM = value.patientHeightCM
            draft.patientWeightKG = value.patientWeightKG
            draft.patientComplaints = value.patientComplaints
            draft.examinationDescription = value.examinationDescription
        } else {
            modelContext.insert(value)
        }
        try modelContext.save()
    }

    public func replaceDraftPhotos(
        values: [USExaminationDraftPhotoDB],
        currentForm: USExaminationDraftDB
    ) throws {
        if let draft = fetchDraft() {
            let previousPhotos = draft.photos
            draft.photos = values
            for photo in previousPhotos {
                modelContext.delete(photo)
            }
        } else {
            currentForm.photos = values
            modelContext.insert(currentForm)
        }
        try modelContext.save()
    }

    public func clearDraft() throws {
        let descriptor = FetchDescriptor<USExaminationDraftDB>()
        let drafts = (try? modelContext.fetch(descriptor)) ?? []
        for draft in drafts {
            modelContext.delete(draft)
        }
        try modelContext.save()
    }

    private func fetchDraft() -> USExaminationDraftDB? {
        let descriptor = FetchDescriptor<USExaminationDraftDB>()
        return try? modelContext.fetch(descriptor).first
    }
}
