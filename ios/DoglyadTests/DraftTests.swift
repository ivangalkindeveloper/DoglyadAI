import Combine
@testable import Doglyad
import DoglyadDatabase
import DoglyadUI
import Foundation
import SwiftData
import Testing
import UIKit

struct DraftTests {
    @Test
    func databaseStoresDraftFieldsAndOrderedPhotos() async throws {
        let schema = Schema([
            USExaminationDraftDB.self,
            USExaminationDraftPhotoDB.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let store = DExaminationDraftStore(modelContainer: container)
        let date = Date(timeIntervalSince1970: 1000000000)
        let form = USExaminationDraftForm(
            examinationNumber: "Examination#7",
            patientName: "Patient#7",
            patientGender: .female,
            patientDateOfBirth: date,
            patientHeightCM: "170.5",
            patientWeightKG: "60.5",
            patientComplaints: "Complaints",
            examinationDescription: "Description"
        )
        let firstPhotoId = UUID()
        let secondPhotoId = UUID()
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 2, height: 2)
        ).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let photos = [
            USExaminationScanPhoto(id: firstPhotoId, image: image),
            USExaminationScanPhoto(id: secondPhotoId, image: image),
        ]

        try await store.upsertDraftForm(value: form.toDB())
        try await store.replaceDraftPhotos(
            values: photos.toDraftDB(),
            currentForm: form.toDB()
        )

        let snapshot = await store.fetchDraft { draft in
            guard let draft else { return Snapshot.empty }
            let value = USExaminationDraft.fromDB(draft)
            return Snapshot(
                examinationNumber: value.form.examinationNumber,
                patientGender: value.form.patientGender,
                patientDateOfBirth: value.form.patientDateOfBirth,
                photoIds: value.photos.map(\.id)
            )
        }

        #expect(snapshot.examinationNumber == form.examinationNumber)
        #expect(snapshot.patientGender == form.patientGender)
        #expect(snapshot.patientDateOfBirth == form.patientDateOfBirth)
        #expect(snapshot.photoIds == [firstPhotoId, secondPhotoId])

        let updatedForm = USExaminationDraftForm(
            examinationNumber: "Examination#8",
            patientName: form.patientName,
            patientGender: form.patientGender,
            patientDateOfBirth: form.patientDateOfBirth,
            patientHeightCM: form.patientHeightCM,
            patientWeightKG: form.patientWeightKG,
            patientComplaints: form.patientComplaints,
            examinationDescription: form.examinationDescription
        )
        try await store.upsertDraftForm(value: updatedForm.toDB())
        let updatedSnapshot = await store.fetchDraft { draft in
            guard let draft else { return Snapshot.empty }
            let value = USExaminationDraft.fromDB(draft)
            return Snapshot(
                examinationNumber: value.form.examinationNumber,
                patientGender: value.form.patientGender,
                patientDateOfBirth: value.form.patientDateOfBirth,
                photoIds: value.photos.map(\.id)
            )
        }

        #expect(updatedSnapshot.examinationNumber == updatedForm.examinationNumber)
        #expect(updatedSnapshot.photoIds == [firstPhotoId, secondPhotoId])

        try await store.clearDraft()
        let isEmpty = await store.fetchDraft { $0 == nil }
        #expect(isEmpty)
    }

    @Test @MainActor
    func autosaverDebouncesChangesAndSavesLatestDraft() async throws {
        let autosaver = DDraftAutosaver<Int>(delay: .milliseconds(20))
        let changes = PassthroughSubject<Void, Never>()
        var currentDraft = 0
        var savedDrafts: [Int] = []

        autosaver.start(
            publishers: [changes.eraseToAnyPublisher()],
            makeDraft: { currentDraft },
            saveDraft: { draft in
                savedDrafts.append(draft)
            }
        )

        currentDraft = 1
        changes.send()
        currentDraft = 2
        changes.send()

        try await Task.sleep(nanoseconds: 60000000)
        await autosaver.waitForPendingSave()

        #expect(savedDrafts == [2])
    }

    @Test @MainActor
    func autosaverFlushesOnlyChangedDraft() async throws {
        let autosaver = DDraftAutosaver<Int>(delay: .milliseconds(20))
        let changes = PassthroughSubject<Void, Never>()
        var currentDraft = 0
        var savedDrafts: [Int] = []

        autosaver.start(
            publishers: [changes.eraseToAnyPublisher()],
            makeDraft: { currentDraft },
            saveDraft: { draft in
                savedDrafts.append(draft)
            }
        )

        autosaver.flush()
        await autosaver.waitForPendingSave()
        #expect(savedDrafts.isEmpty)

        currentDraft = 1
        changes.send()
        autosaver.flush()
        await autosaver.waitForPendingSave()
        try await Task.sleep(nanoseconds: 60000000)
        await autosaver.waitForPendingSave()
        #expect(savedDrafts == [1])
    }

    @Test @MainActor
    func autosaverObservesFormattedTextFieldControllerChanges() async throws {
        let controller = DTextFieldController(
            initialText: "170",
            formatters: [DTextFieldDecimalFormatter()]
        )
        let autosaver = DDraftAutosaver<String>(delay: .milliseconds(20))
        var savedDrafts: [String] = []

        autosaver.start(
            publishers: [
                controller.$text
                    .dropFirst()
                    .map { _ in () }
                    .eraseToAnyPublisher(),
            ],
            makeDraft: { controller.text },
            saveDraft: { draft in
                savedDrafts.append(draft)
            }
        )

        controller.setText("185")
        try await Task.sleep(nanoseconds: 60000000)
        await autosaver.waitForPendingSave()

        #expect(savedDrafts == ["185"])
    }
}

private extension DraftTests {
    struct Snapshot: Sendable {
        static let empty = Snapshot(
            examinationNumber: "",
            patientGender: .male,
            patientDateOfBirth: .distantPast,
            photoIds: []
        )

        let examinationNumber: String
        let patientGender: PatientGender
        let patientDateOfBirth: Date
        let photoIds: [UUID]
    }
}
