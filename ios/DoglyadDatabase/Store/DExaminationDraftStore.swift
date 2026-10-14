import Foundation
import SwiftData

@ModelActor
public actor DExaminationDraftStore {
    public func fetchDraft<T: Sendable>(
        _ transform: @Sendable (USExaminationDraftDB?) -> T,
    ) throws -> T {
        try transform(
            fetchDraft(),
        )
    }

    public func upsertDraftForm(
        value: USExaminationDraftDB,
    ) throws {
        if let draft = try fetchDraft() {
            draft.examinationNumber = value.examinationNumber
            draft.patientName = value.patientName
            draft.patientGenderRawValue = value.patientGenderRawValue
            draft.patientDateOfBirth = value.patientDateOfBirth
            draft.patientHeightCM = value.patientHeightCM
            draft.patientWeightKG = value.patientWeightKG
            draft.patientComplaints = value.patientComplaints
            draft.examinationDescription = value.examinationDescription
        } else {
            modelContext.insert(
                value,
            )
        }
        try saveChanges()
    }

    public func replaceDraftPhotos(
        values: [USExaminationDraftPhotoDB],
        currentForm: USExaminationDraftDB,
    ) throws {
        if let draft = try fetchDraft() {
            let previousPhotos = draft.photos
            draft.photos = values
            for photo in previousPhotos {
                modelContext.delete(
                    photo,
                )
            }
        } else {
            currentForm.photos = values
            modelContext.insert(
                currentForm,
            )
        }
        try saveChanges()
    }

    public func clearDraft() throws {
        let descriptor = FetchDescriptor<USExaminationDraftDB>()
        let drafts = try modelContext.fetch(
            descriptor,
        )
        for draft in drafts {
            modelContext.delete(
                draft,
            )
        }
        try saveChanges()
    }

    private func fetchDraft() throws -> USExaminationDraftDB? {
        let descriptor = FetchDescriptor<USExaminationDraftDB>()
        return try modelContext.fetch(
            descriptor,
        ).first
    }

    private func saveChanges() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
