import Foundation

@frozen public enum VoiceFieldValue: Equatable, Sendable {
    case text(String)
    case gender(VoiceGender)
    case date(Date)
    case number(Double)

    static func parse(fieldId: VoiceFieldId, text: String, locale: Locale) throws -> Self {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DictationProposalError.invalidValue(fieldId) }

        switch fieldId {
        case .examinationNumber, .patientName, .patientComplaints, .examinationDescription:
            return .text(text)
        case .patientGender:
            guard let gender = VoiceGender(rawValue: trimmed) else {
                throw DictationProposalError.invalidValue(fieldId)
            }
            return .gender(gender)
        case .patientDateOfBirth:
            guard let date = parseCompleteDate(trimmed, locale: locale) else {
                throw DictationProposalError.invalidValue(fieldId)
            }
            return .date(date)
        case .patientHeightCM, .patientWeightKG:
            guard let number = Double(trimmed), number.isFinite, number > 0 else {
                throw DictationProposalError.invalidValue(fieldId)
            }
            return .number(number)
        }
    }

    private static func parseCompleteDate(_ text: String, locale: Locale) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: text), iso.string(from: date) == text {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        for format in ["MMMM d, yyyy", "MMMM d yyyy", "MMM d, yyyy", "d MMMM yyyy", "d MMMM yyyy 'года'"] {
            formatter.dateFormat = format
            guard let date = formatter.date(from: text),
                  formatter.string(from: date).localizedCaseInsensitiveCompare(text) == .orderedSame
            else { continue }
            return date
        }
        return nil
    }
}
