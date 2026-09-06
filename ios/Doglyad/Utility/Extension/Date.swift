import Foundation

extension Date {
    func localized(
        locale: Locale = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }

    func localizedDayTitle(
        relativeTo now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .current
    ) -> String {
        let day = calendar.startOfDay(for: self)
        let today = calendar.startOfDay(for: now)

        if day == today {
            return String(localized: "dateTodayLabel", locale: locale)
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           day == yesterday
        {
            return String(localized: "dateYesterdayLabel", locale: locale)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone

        if calendar.component(.year, from: day) == calendar.component(.year, from: today) {
            formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        } else if locale.identifier.lowercased().hasPrefix("ru") {
            formatter.dateFormat = "d MMMM yyyy"
        } else {
            formatter.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        }

        return formatter.string(from: day)
    }
}
