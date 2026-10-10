import Foundation

class DNeuralUltrasoundLegacyGenerationConfig {
    static let dateFormat: String = "yyyy-MM-dd"
    static let promptDateFormat: String = "YYYY-MM-DD"
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale(
            identifier: "en_US_POSIX",
        )
        formatter.timeZone = TimeZone(
            secondsFromGMT: 0,
        )
        formatter.calendar = Calendar(
            identifier: .gregorian,
        )
        return formatter
    }()

    static func userPrompt(
        for dictation: String,
    ) -> String {
        """
        <dictation>
        \(dictation)
        </dictation>
        """
    }
}
