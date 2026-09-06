@testable import Doglyad
import DoglyadDatabase
import Foundation
import SwiftData
import Testing

struct HistoryTests {
    @Test
    func daySectionsMergeAcrossPageBoundaryAndFormatRussianTitles() {
        let calendar = calendar()
        let builder = HistoryDaySectionBuilder(
            calendar: calendar,
            locale: Locale(identifier: "ru_RU")
        )
        let now = date(year: 2026, month: 9, day: 5, hour: 12, calendar: calendar)

        let firstPage = [
            conclusion(at: date(year: 2026, month: 9, day: 5, hour: 12, calendar: calendar)),
            conclusion(at: date(year: 2026, month: 9, day: 5, hour: 8, calendar: calendar)),
            conclusion(at: date(year: 2026, month: 9, day: 4, hour: 18, calendar: calendar)),
        ]
        let secondPage = [
            conclusion(at: date(year: 2026, month: 9, day: 4, hour: 7, calendar: calendar)),
            conclusion(at: date(year: 2026, month: 3, day: 20, hour: 18, calendar: calendar)),
            conclusion(at: date(year: 2025, month: 3, day: 20, hour: 18, calendar: calendar)),
        ]

        let firstSections = builder.appending(firstPage, to: [], relativeTo: now)
        let sections = builder.appending(secondPage, to: firstSections, relativeTo: now)

        #expect(sections.map(\.title) == ["Сегодня", "Вчера", "20 марта", "20 марта 2025"])
        #expect(sections.map(\.conclusions.count) == [2, 2, 1, 1])
    }

    @Test
    func databaseFetchesConclusionPagesNewestFirst() async throws {
        let schema = Schema([
            NeuralModelSettingsDB.self,
            USExaminationConclusionDB.self,
            USExaminationDataDB.self,
            USExaminationScanPhotoDB.self,
            USExaminationModelConclusionDB.self,
            USExaminationTemplateDB.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let store = DExaminationConclusionsStore(modelContainer: container)
        let newestDate = Date(timeIntervalSince1970: 2000000000)

        for index in 0 ..< 45 {
            try await store.setExaminationConclusion(
                value: databaseConclusion(
                    at: newestDate.addingTimeInterval(-Double(index))
                )
            )
        }

        let firstPage = await store.fetchExaminationConclusions(limit: 20, offset: 0) {
            $0.map(\.date)
        }
        let secondPage = await store.fetchExaminationConclusions(limit: 20, offset: 20) {
            $0.map(\.date)
        }
        let thirdPage = await store.fetchExaminationConclusions(limit: 20, offset: 40) {
            $0.map(\.date)
        }
        let count = await store.fetchExaminationConclusionsCount()

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

    private func conclusion(at date: Date) -> USExaminationConclusion {
        USExaminationConclusion(
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
                patientName: "Patient",
                patientGender: .male,
                patientDateOfBirth: date,
                patientHeight: 180,
                patientWeight: 80,
                patientComplaint: "",
                examinationDescription: ""
            ),
            actualModelConclusion: USExaminationModelConclusion(
                date: date,
                modelId: "test",
                response: ""
            ),
            previosModelConclusions: []
        )
    }

    private func databaseConclusion(at date: Date) -> USExaminationConclusionDB {
        USExaminationConclusionDB(
            date: date,
            neuralModelSettings: NeuralModelSettingsDB(
                selectedNeuralModelId: nil,
                temperature: nil,
                maxTokens: nil
            ),
            examinationData: USExaminationDataDB(
                usExaminationTypeId: "test",
                patientName: "Patient",
                patientGenderRawValue: "male",
                patientDateOfBirth: date,
                patientHeight: 180,
                patientWeight: 80,
                patientComplaint: "",
                examinationDescription: ""
            ),
            actualModelConclusion: USExaminationModelConclusionDB(
                date: date,
                modelId: "test",
                response: ""
            ),
            previosModelConclusions: []
        )
    }
}
