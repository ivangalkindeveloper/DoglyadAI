@testable import Doglyad
import DoglyadDatabase
@testable import DoglyadNetwork
import Foundation
import SwiftData
import Testing

struct ReportStreamingTests {
    @Test
    func eventDecoderKeepsUTF8AcrossChunksAndRejectsTruncation() throws {
        let wire = Data(
            "id: 12\r\nevent: reportDelta\r\ndata: Привет\r\ndata: 世界\r\n\r\n".utf8,
        )
        var decoder = DServerEventDecoder()
        var events: [DServerEvent] = []
        for byte in wire {
            events += try decoder.append(
                Data(
                    [byte],
                ),
            )
        }
        try decoder.finish()
        #expect(
            events.count == 1,
        )
        #expect(
            events.first?.id == "12",
        )
        #expect(
            events.first?.event == "reportDelta",
        )
        #expect(
            events.first?.data == Data(
                "Привет\n世界".utf8,
            ),
        )
        _ = try decoder.append(
            Data(
                "data: unfinished".utf8,
            ),
        )
        #expect(
            throws: URLError.self,
        ) {
            try decoder.finish()
        }
    }

    @Test
    func finalServerSnapshotDecodesDateAndDoesNotTreatPreviewAsFinal() throws {
        let json = #"{"modelId":"test","generationId":"11111111-1111-1111-1111-111111111111","status":"completed","sequence":7,"partialReport":{"description":"Preview"},"report":{"date":"2026-11-01T10:00:00.123456Z","modelId":"test","description":"Validated","conclusion":"Conclusion","photoRemarks":[]},"errorCode":null}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(
            USReportGenerationResponse.self,
            from: Data(
                json.utf8,
            ),
        )
        #expect(
            result.report?.description == "Validated",
        )
        #expect(
            result.partialReport.description == "Preview",
        )
        #expect(
            result.report?.generation.status == .completed,
        )
    }

    @MainActor @Test
    func persistenceKeepsAttemptIdentityAndOldReportsDefaultToCompleted() throws {
        let container = try ModelContainer(
            for: USExaminationModelReportDB.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
            ),
        )
        let context = ModelContext(
            container,
        )
        let id = UUID()
        let model = USExaminationModelReport(
            date: Date(),
            modelId: "test",
            description: "Partial",
            conclusion: "",
            recommendations: nil,
            generation: USReportGeneration(
                status: .interrupted,
                id: id,
                requestData: Data(
                    "snapshot".utf8,
                ),
                sequence: 4,
            ),
        )
        context.insert(
            model.toDB(),
        )
        let old = USExaminationModelReportDB(
            date: Date(),
            modelId: "old",
            description: "Original",
            conclusion: "Original conclusion",
            recommendations: nil,
        )
        context.insert(
            old,
        )
        try context.save()
        let rows = try context.fetch(
            FetchDescriptor<USExaminationModelReportDB>(),
        )
        let row = try #require(
            rows.first(
                where: {
                    $0.generation?.id == id
                },
            ),
        )
        let restored = USExaminationModelReport.fromDB(
            row,
        )
        #expect(
            restored.generation.status == .interrupted,
        )
        #expect(
            restored.generation.requestData == Data(
                "snapshot".utf8,
            ),
        )
        #expect(
            restored.generation.sequence == 4,
        )
        #expect(
            USExaminationModelReport.fromDB(
                old,
            ).generation.status == .completed,
        )
    }

    @MainActor @Test
    func startupInterruptionAndPartialWritesKeepOneHistoryEntry() async throws {
        let container = try ModelContainer(
            for: USExaminationReportDB.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
            ),
        )
        let store = DExaminationReportsStore(
            modelContainer: container,
        )
        let generationId = UUID()
        let model = USExaminationModelReport(
            date: Date(),
            modelId: "test",
            description: "Partial",
            conclusion: "",
            recommendations: nil,
            generation: USReportGeneration(
                status: .generating,
                id: generationId,
                requestData: Data(
                    "request".utf8,
                ),
                sequence: 1,
            ),
        )
        let report = USExaminationReport(
            date: Date(),
            settingsAI: SettingsAI(
                selectedNeuralModelId: "test",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "bladder",
                photos: [],
                examinationNumber: "1",
                patientName: "Synthetic",
                patientGender: .female,
                patientDateOfBirth: Date(),
                isPatientConsent: true,
                patientHeight: nil,
                patientWeight: nil,
                patientComplaints: nil,
                examinationDescription: "Synthetic",
            ),
            actualModelReport: model,
            previousModelReports: [],
        )
        try await store.setExaminationReport(
            value: report.toDB(),
        )
        try await store.updateGenerations(
            fromStatus: USReportGenerationStatus.generating.rawValue,
            toStatus: USReportGenerationStatus.interrupted.rawValue,
        )
        let interrupted = try await store.fetchExaminationReports(
            limit: 10,
            offset: 0,
        ) {
            $0.map {
                USExaminationReport.fromDB(
                    $0,
                )
            }
        }
        #expect(
            interrupted.first?.actualModelReport.generation.status == .interrupted,
        )
        #expect(
            interrupted.first?.actualModelReport.description == "Partial",
        )
        var complete = model
        complete.generation.status = .completed
        complete.generation.sequence = 2
        try await store.updateGeneratedReport(
            reportId: report.id,
            generationId: generationId,
            value: complete.toDB(),
        )
        // A late callback from another attempt must not overwrite the completed result.
        try await store.updateGeneratedReport(
            reportId: report.id,
            generationId: UUID(),
            value: model.toDB(),
        )
        let stored = try await store.fetchExaminationReports(
            limit: 10,
            offset: 0,
        ) {
            $0.map {
                USExaminationReport.fromDB(
                    $0,
                )
            }
        }
        let saved = try #require(
            stored.first,
        )
        #expect(
            saved.actualModelReport.generation.status == .completed,
        )
        #expect(
            saved.actualModelReport.generation.sequence == 2,
        )
        try await store.updateGenerations(
            fromStatus: USReportGenerationStatus.generating.rawValue,
            toStatus: USReportGenerationStatus.interrupted.rawValue,
        )
        let afterRestart = try await store.fetchExaminationReports(
            limit: 10,
            offset: 0,
        ) {
            $0.map {
                USExaminationReport.fromDB(
                    $0,
                )
            }
        }
        #expect(
            afterRestart.first?.actualModelReport.generation.status == .completed,
        )
        let count = try await store.fetchExaminationReportsCount()
        #expect(
            count == 1,
        )
    }
}
