import Foundation

struct HistoryDaySectionBuilder {
    private let calendar: Calendar
    private let locale: Locale
    private let todayTitle: String
    private let yesterdayTitle: String

    init(
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .current,
        todayTitle: String,
        yesterdayTitle: String,
    ) {
        self.calendar = calendar
        self.locale = locale
        self.todayTitle = todayTitle
        self.yesterdayTitle = yesterdayTitle
    }

    func appending(
        _ reports: [USExaminationReport],
        to existingSections: [HistoryDaySection],
        relativeTo now: Date = Date(),
    ) -> [HistoryDaySection] {
        var sections = existingSections

        for report in reports {
            let day = calendar.startOfDay(
                for: report.date,
            )

            if sections.last?.day == day {
                sections[
                    sections.count - 1,
                ].reports.append(
                    report,
                )
            } else {
                sections.append(
                    HistoryDaySection(
                        day: day,
                        title: day.localizedDayTitle(
                            todayTitle: todayTitle,
                            yesterdayTitle: yesterdayTitle,
                            relativeTo: now,
                            calendar: calendar,
                            locale: locale,
                        ),
                        reports: [report],
                    ),
                )
            }
        }

        return sections
    }
}
