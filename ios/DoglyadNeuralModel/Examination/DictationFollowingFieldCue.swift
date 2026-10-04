import Foundation

/// A new record reference after a clinical sentence is another form field,
/// not part of the ultrasound finding.
enum DictationFollowingFieldCue {
    static let recordPattern = #"(?:this\s+was\s+filed\s+as\s+study|this\s+belongs\s+to\s+protocol|(?:the\s+)?(?:reference|registration|case|visit|protocol)\s+number|(?:the\s+)?case\s+number\s+was|запись\s+оформлена\s+под\s+номером|регистрационный\s+номер|номер\s+(?:протокола|случая|визита)|это\s+протокол)"#

    static func isInsideDescription(_ text: String) -> Bool {
        text.range(
            of: #"(?:[.;]|\n)\s*"# + recordPattern + #"\s+[0-9]+"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
