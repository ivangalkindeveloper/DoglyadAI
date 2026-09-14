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
            ids = RecentUSExaminationTypes.recording(id, in: ids)
        }

        #expect(ids == ["b", "d", "c"])
    }

    @Test
    func unavailableRecentExaminationTypesAreRemovedDuringInitialization() {
        let ids = RecentUSExaminationTypes.available(
            from: ["removed", "a", "a", "b", "c", "d"],
            availableIds: ["a", "b", "c", "d"]
        )

        #expect(ids == ["a", "b", "c"])
    }

    @Test
    func daySectionsMergeAcrossPageBoundaryAndFormatRussianTitles() {
        let calendar = calendar()
        let builder = HistoryDaySectionBuilder(
            calendar: calendar,
            locale: Locale(identifier: "ru_RU")
        )
        let now = date(year: 2026, month: 9, day: 5, hour: 12, calendar: calendar)

        let firstPage = [
            report(at: date(year: 2026, month: 9, day: 5, hour: 12, calendar: calendar)),
            report(at: date(year: 2026, month: 9, day: 5, hour: 8, calendar: calendar)),
            report(at: date(year: 2026, month: 9, day: 4, hour: 18, calendar: calendar)),
        ]
        let secondPage = [
            report(at: date(year: 2026, month: 9, day: 4, hour: 7, calendar: calendar)),
            report(at: date(year: 2026, month: 3, day: 20, hour: 18, calendar: calendar)),
            report(at: date(year: 2025, month: 3, day: 20, hour: 18, calendar: calendar)),
        ]

        let firstSections = builder.appending(firstPage, to: [], relativeTo: now)
        let sections = builder.appending(secondPage, to: firstSections, relativeTo: now)

        #expect(sections.map(\.title) == ["Сегодня", "Вчера", "20 марта", "20 марта 2025"])
        #expect(sections.map(\.reports.count) == [2, 2, 1, 1])
    }

    @Test
    func databaseFetchesReportPagesNewestFirst() async throws {
        let schema = Schema([
            NeuralModelSettingsDB.self,
            USExaminationReportDB.self,
            USExaminationDataDB.self,
            USExaminationScanPhotoDB.self,
            USExaminationModelReportDB.self,
            USExaminationTemplateDB.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let store = DExaminationReportsStore(modelContainer: container)
        let newestDate = Date(timeIntervalSince1970: 2000000000)

        for index in 0 ..< 45 {
            try await store.setExaminationReport(
                value: databaseReport(
                    at: newestDate.addingTimeInterval(-Double(index))
                )
            )
        }

        let firstPage = await store.fetchExaminationReports(limit: 20, offset: 0) {
            $0.map(\.date)
        }
        let secondPage = await store.fetchExaminationReports(limit: 20, offset: 20) {
            $0.map(\.date)
        }
        let thirdPage = await store.fetchExaminationReports(limit: 20, offset: 40) {
            $0.map(\.date)
        }
        let count = await store.fetchExaminationReportsCount()

        #expect(firstPage.count == 20)
        #expect(secondPage.count == 20)
        #expect(thirdPage.count == 5)
        #expect(count == 45)
        #expect(firstPage.first == newestDate)
        #expect(secondPage.first == newestDate.addingTimeInterval(-20))
        #expect(thirdPage.first == newestDate.addingTimeInterval(-40))
        #expect(Set(firstPage).isDisjoint(with: Set(secondPage)))
        #expect(Set(secondPage).isDisjoint(with: Set(thirdPage)))
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }

    private func report(at date: Date) -> USExaminationReport {
        USExaminationReport(
            date: date,
            neuralModelSettings: NeuralModelSettings(
                selectedNeuralModelId: nil,
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil
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
                patientComplaint: "",
                examinationDescription: ""
            ),
            actualModelReport: USExaminationModelReport(
                date: date,
                modelId: "test",
                description: "Description",
                conclusion: "Conclusion",
                recommendations: "Recommendations"
            ),
            previousModelReports: []
        )
    }

    private func databaseReport(at date: Date) -> USExaminationReportDB {
        USExaminationReportDB(
            date: date,
            neuralModelSettings: NeuralModelSettingsDB(
                selectedNeuralModelId: nil,
                temperature: nil,
                maxTokens: nil
            ),
            examinationData: USExaminationDataDB(
                usExaminationTypeId: "test",
                examinationNumber: "Examination#0",
                patientName: "Patient",
                patientGenderRawValue: "male",
                patientDateOfBirth: date,
                patientHeight: 180,
                patientWeight: 80,
                patientComplaint: "",
                examinationDescription: ""
            ),
            actualModelReport: USExaminationModelReportDB(
                date: date,
                modelId: "test",
                description: "Description",
                conclusion: "Conclusion",
                recommendations: "Recommendations"
            ),
            previousModelReports: []
        )
    }
}
