@testable import Doglyad
import DoglyadDatabase
import Foundation
import SwiftData
import Testing

struct HistoryTests {
    @Test
    func recentExaminationTypesKeepThreeUniqueSelectionsNewestFirst() {
        var ids: [String] = []
        for id in ["a", "b", "c", "d", "b"] {
            ids = USExaminationRecentTypes.recording(
                id,
                in: ids,
            )
        }

        #expect(
            ids == ["b", "d", "c"],
        )
    }

    @Test
    func unavailableRecentExaminationTypesAreRemovedDuringInitialization() {
        let ids = USExaminationRecentTypes.available(
            from: ["removed", "a", "a", "b", "c", "d"],
            availableIds: ["a", "b", "c", "d"],
        )

        #expect(
            ids == ["a", "b", "c"],
        )
    }

    @Test
    func daySectionsMergeAcrossPageBoundaryAndFormatRussianTitles() {
        let calendar = calendar()
        let builder = HistoryDaySectionBuilder(
            todayTitle: "Сегодня",
            yesterdayTitle: "Вчера",
            calendar: calendar,
            locale: Locale(
                identifier: "ru_RU",
            ),
        )
        let now = date(
            year: 2026,
            month: 9,
            day: 5,
            hour: 12,
            calendar: calendar,
        )

        let firstPage = [
            report(
                at: date(
                    year: 2026,
                    month: 9,
                    day: 5,
                    hour: 12,
                    calendar: calendar,
                ),
            ),
            report(
                at: date(
                    year: 2026,
                    month: 9,
                    day: 5,
                    hour: 8,
                    calendar: calendar,
                ),
            ),
            report(
                at: date(
                    year: 2026,
                    month: 9,
                    day: 4,
                    hour: 18,
                    calendar: calendar,
                ),
            ),
        ]
        let secondPage = [
            report(
                at: date(
                    year: 2026,
                    month: 9,
                    day: 4,
                    hour: 7,
                    calendar: calendar,
                ),
            ),
            report(
                at: date(
                    year: 2026,
                    month: 3,
                    day: 20,
                    hour: 18,
                    calendar: calendar,
                ),
            ),
            report(
                at: date(
                    year: 2025,
                    month: 3,
                    day: 20,
                    hour: 18,
                    calendar: calendar,
                ),
            ),
        ]

        let firstSections = builder.appending(
            firstPage,
            to: [],
            relativeTo: now,
        )
        let sections = builder.appending(
            secondPage,
            to: firstSections,
            relativeTo: now,
        )

        #expect(
            sections.map(
                \.title,
            ) == ["Сегодня", "Вчера", "20 марта", "20 марта 2025"],
        )
        #expect(
            sections.map(
                \.reports.count,
            ) == [2, 2, 1, 1],
        )
    }

    @Test
    func historyClearRemovesOwnedAndLegacyOrphanRecordsButKeepsTemplates() async throws {
        let schema = Schema(
            [
                USExaminationReportDB.self,
                SettingsAIDB.self,
                USExaminationDataDB.self,
                USExaminationScanPhotoDB.self,
                USExaminationModelReportDB.self,
                USExaminationPhotoRemarksDB.self,
                USExaminationPhotoRemarkPointDB.self,
                USReportGenerationDB.self,
                USExaminationTemplateDB.self,
            ],
        )
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
            ),
        )
        let store = DExaminationReportsStore(
            modelContainer: container,
        )
        let report = databaseReport(
            at: Date(),
        )
        report.examinationData.photos = [USExaminationScanPhotoDB(
            data: Data(
                [1, 2, 3],
            ),
        )]
        try await store.setExaminationReport(
            value: report,
        )
        // Old application versions left these records after deleting their report.
        let context = ModelContext(
            container,
        )
        let legacy = databaseReport(
            at: Date(),
        )
        context.insert(
            legacy.settingsAI,
        )
        context.insert(
            legacy.examinationData,
        )
        context.insert(
            USExaminationScanPhotoDB(
                data: Data(
                    [4, 5, 6],
                ),
            ),
        )
        let templateID = UUID()
        context.insert(
            USExaminationTemplateDB(
                id: templateID,
                usExaminationTypeId: "test",
                name: "Keep",
                content: "Full template",
            ),
        )
        try context.save()
        try await store.clearAllExaminationReports()
        let check = ModelContext(
            container,
        )
        #expect(
            try check.fetchCount(
                FetchDescriptor<USExaminationReportDB>(),
            ) == 0,
        )
        #expect(
            try check.fetchCount(
                FetchDescriptor<USExaminationDataDB>(),
            ) == 0,
        )
        #expect(
            try check.fetchCount(
                FetchDescriptor<SettingsAIDB>(),
            ) == 0,
        )
        #expect(
            try check.fetchCount(
                FetchDescriptor<USExaminationScanPhotoDB>(),
            ) == 0,
        )
        #expect(
            try check.fetchCount(
                FetchDescriptor<USExaminationModelReportDB>(),
            ) == 0,
        )
        #expect(
            try check.fetchCount(
                FetchDescriptor<USExaminationPhotoRemarksDB>(),
            ) == 0,
        )
        #expect(
            try check.fetchCount(
                FetchDescriptor<USExaminationPhotoRemarkPointDB>(),
            ) == 0,
        )
        #expect(
            try check.fetchCount(
                FetchDescriptor<USReportGenerationDB>(),
            ) == 0,
        )
        let templates = try check.fetch(
            FetchDescriptor<USExaminationTemplateDB>(),
        )
        #expect(
            templates.count == 1,
        )
        #expect(
            templates.first?.id == templateID,
        )
        #expect(
            templates.first?.content == "Full template",
        )
    }

    @Test
    func databaseFetchesReportPagesNewestFirst() async throws {
        let schema = Schema(
            [
                SettingsAIDB.self,
                USExaminationReportDB.self,
                USExaminationDataDB.self,
                USExaminationScanPhotoDB.self,
                USExaminationModelReportDB.self,
                USExaminationTemplateDB.self,
            ],
        )
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
        )
        let container = try ModelContainer(
            for: schema,
            configurations: configuration,
        )
        let store = DExaminationReportsStore(
            modelContainer: container,
        )
        let newestDate = Date(
            timeIntervalSince1970: 2000000000,
        )

        do {
            try await store.updateExaminationReport(
                value: databaseReport(
                    at: newestDate,
                ),
            )
            Issue.record(
                "Updating a missing report must fail",
            )
        } catch {
            #expect(
                error as? DDatabaseError == .examinationReportNotFound,
            )
        }

        for index in 0 ..< 45 {
            try await store.setExaminationReport(
                value: databaseReport(
                    at: newestDate.addingTimeInterval(
                        -Double(
                            index,
                        ),
                    ),
                ),
            )
        }

        let firstPage = try await store.fetchExaminationReports(
            limit: 20,
            offset: 0,
        ) {
            $0.map(
                \.date,
            )
        }
        let secondPage = try await store.fetchExaminationReports(
            limit: 20,
            offset: 20,
        ) {
            $0.map(
                \.date,
            )
        }
        let thirdPage = try await store.fetchExaminationReports(
            limit: 20,
            offset: 40,
        ) {
            $0.map(
                \.date,
            )
        }
        let count = try await store.fetchExaminationReportsCount()

        #expect(
            firstPage.count == 20,
        )
        #expect(
            secondPage.count == 20,
        )
        #expect(
            thirdPage.count == 5,
        )
        #expect(
            count == 45,
        )
        #expect(
            firstPage.first == newestDate,
        )
        #expect(
            secondPage.first == newestDate.addingTimeInterval(
                -20,
            ),
        )
        #expect(
            thirdPage.first == newestDate.addingTimeInterval(
                -40,
            ),
        )
        #expect(
            Set(
                firstPage,
            ).isDisjoint(
                with: Set(
                    secondPage,
                ),
            ),
        )
        #expect(
            Set(
                secondPage,
            ).isDisjoint(
                with: Set(
                    thirdPage,
                ),
            ),
        )
    }

    @Test
    func reportWithoutMeasurementsCanBeStoredAndEncoded() async throws {
        let schema = Schema(
            [
                SettingsAIDB.self,
                USExaminationReportDB.self,
                USExaminationDataDB.self,
                USExaminationScanPhotoDB.self,
                USExaminationModelReportDB.self,
            ],
        )
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
        )
        let container = try ModelContainer(
            for: schema,
            configurations: configuration,
        )
        let store = DExaminationReportsStore(
            modelContainer: container,
        )
        let report = databaseReport(
            at: Date(),
        )
        report.examinationData.patientHeight = nil
        report.examinationData.patientWeight = nil
        try await store.setExaminationReport(
            value: report,
        )

        let examinations = try await store.fetchExaminationReports(
            limit: 1,
            offset: 0,
        ) {
            $0.map {
                USExaminationData.fromDB(
                    $0.examinationData,
                )
            }
        }
        let examination = try #require(
            examinations.first,
        )
        #expect(
            examination.patientHeight == nil,
        )
        #expect(
            examination.patientWeight == nil,
        )

        let encoded = try JSONEncoder().encode(
            examination,
        )
        let json = try #require(
            JSONSerialization.jsonObject(
                with: encoded,
            ) as? [String: Any],
        )
        #expect(
            json[
                "patientHeight",
            ] == nil,
        )
        #expect(
            json[
                "patientWeight",
            ] == nil,
        )
        let decoded = try JSONDecoder().decode(
            USExaminationData.self,
            from: encoded,
        )
        #expect(
            decoded.patientHeight == nil,
        )
        #expect(
            decoded.patientWeight == nil,
        )
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(
            identifier: .gregorian,
        )
        calendar.timeZone = TimeZone(
            secondsFromGMT: 0,
        )!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar,
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
            ),
        )!
    }

    private func report(
        at date: Date,
    ) -> USExaminationReport {
        USExaminationReport(
            date: date,
            settingsAI: SettingsAI(
                selectedNeuralModelId: nil,
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "test",
                photos: [],
                examinationNumber: "Examination#0",
                patientName: "Patient",
                patientGender: .male,
                patientDateOfBirth: date,
                patientHeight: 180,
                patientWeight: 80,
                patientComplaints: "",
                examinationDescription: "",
            ),
            actualModelReport: USExaminationModelReport(
                date: date,
                modelId: "test",
                description: "Description",
                conclusion: "Conclusion",
                recommendations: "Recommendations",
            ),
            previousModelReports: [],
        )
    }

    private func databaseReport(
        at date: Date,
    ) -> USExaminationReportDB {
        USExaminationReportDB(
            date: date,
            settingsAI: SettingsAIDB(
                selectedNeuralModelId: nil,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationDataDB(
                usExaminationTypeId: "test",
                examinationNumber: "Examination#0",
                patientName: "Patient",
                patientGenderRawValue: "male",
                patientDateOfBirth: date,
                patientHeight: 180,
                patientWeight: 80,
                patientComplaints: "",
                examinationDescription: "",
            ),
            actualModelReport: USExaminationModelReportDB(
                date: date,
                modelId: "test",
                description: "Description",
                conclusion: "Conclusion",
                recommendations: "Recommendations",
            ),
            previousModelReports: [],
        )
    }
}
