@testable import Doglyad
import DoglyadDatabase
import Foundation
import SwiftData
import Testing

@MainActor
struct PatientConsentPersistenceTests {
    @Test(
        arguments: [false, true],
    )
    func consentSurvivesDatabaseAndRequestRoundTrips(
        isPatientConsent: Bool,
    ) throws {
        let container = try ModelContainer(
            for: USExaminationDataDB.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
            ),
        )
        let original = ModulePreviewFactory.report.examinationData.toDB()
        original.photos = []
        original.isPatientConsent = isPatientConsent
        let context = ModelContext(
            container,
        )
        context.insert(
            original,
        )
        try context.save()
        let restoredContext = ModelContext(
            container,
        )
        let restored = try #require(
            restoredContext.fetch(
                FetchDescriptor<USExaminationDataDB>(),
            ).first,
        )
        let data = USExaminationData.fromDB(
            restored,
        )
        #expect(
            data.isPatientConsent == isPatientConsent,
        )
        #expect(
            data.toDB().isPatientConsent == isPatientConsent,
        )
        let encoded = try JSONEncoder().encode(
            data,
        )
        let json = try #require(
            JSONSerialization.jsonObject(
                with: encoded,
            ) as? [String: Any],
        )
        #expect(
            json[
                "isPatientConsent",
            ] as? Bool == isPatientConsent,
        )
        #expect(
            try JSONDecoder().decode(
                USExaminationData.self,
                from: encoded,
            ) == data,
        )
    }
}
