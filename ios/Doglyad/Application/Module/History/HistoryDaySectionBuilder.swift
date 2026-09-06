import Foundation

struct HistoryDaySectionBuilder {
    private let calendar: Calendar
    private let locale: Locale

    init(
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .current
    ) {
        self.calendar = calendar
        self.locale = locale
    }

    func appending(
        _ conclusions: [USExaminationConclusion],
        to existingSections: [HistoryDaySection],
        relativeTo now: Date = Date()
    ) -> [HistoryDaySection] {
        var sections = existingSections

        for conclusion in conclusions {
            let day = calendar.startOfDay(for: conclusion.date)

            if sections.last?.day == day {
                sections[sections.count - 1].conclusions.append(conclusion)
            } else {
                sections.append(
                    HistoryDaySection(
                        day: day,
                        title: day.localizedDayTitle(
                            relativeTo: now,
                            calendar: calendar,
                            locale: locale
                        ),
                        conclusions: [conclusion]
                    )
                )
            }
        }

        return sections
    }
}
