import Foundation

/// Flags explicit contradictions between a proposal and its dictated evidence.
/// An empty warning list does not establish clinical equivalence; the physician
/// still reviews and selects each field before it changes the form.
enum DictationProposalValidator {
    static func warnings(
        fieldId: VoiceFieldId,
        value: VoiceFieldValue,
        sourceQuote: String,
        request: DictationParseRequest
    ) -> [VoiceProposalWarning] {
        let source = DictationTextFacts(sourceQuote, locale: request.locale)
        var warnings: [VoiceProposalWarning] = []

        switch fieldId {
        case .examinationNumber:
            guard case let .text(number) = value else { return [.identifierMismatch] }
            if !hasCitedIdentifier(number, in: sourceQuote, locale: request.locale) {
                warnings.append(.identifierMismatch)
            }
        case .patientName:
            guard case let .text(name) = value else { return [.textChanged] }
            if !source.containsLiteral(DictationTextFacts(name, locale: request.locale)) {
                warnings.append(.textChanged)
            }
        case .patientGender:
            guard case let .gender(gender) = value else { return [.genderUnverified] }
            let spoken = spokenGenders(source.tokens)
            if spoken.count != 1 || !spoken.contains(gender) {
                warnings.append(.genderUnverified)
            }
        case .patientDateOfBirth:
            guard case let .date(date) = value else { return [.dateUnverified] }
            let spokenDates = dates(in: sourceQuote, locale: request.locale)
            if !spokenDates.contains(date) { warnings.append(.dateUnverified) }
            if spokenDates.count > 1 { warnings.append(.ambiguousDictation) }
        case .patientHeightCM:
            guard case let .number(number) = value else { return [.numberMismatch] }
            warnings.append(contentsOf: measurementWarnings(
                number: number,
                source: source,
                locale: request.locale,
                conversions: [.centimeter: 1, .meter: 100]
            ))
        case .patientWeightKG:
            guard case let .number(number) = value else { return [.numberMismatch] }
            warnings.append(contentsOf: measurementWarnings(
                number: number,
                source: source,
                locale: request.locale,
                conversions: [.kilogram: 1, .gram: 0.001]
            ))
        case .patientComplaints, .examinationDescription:
            guard case let .text(text) = value else { return [.textChanged] }
            let proposed = DictationTextFacts(text, locale: request.locale)
            if source.sides != proposed.sides { warnings.append(.sideMismatch) }
            if source.negationCount != proposed.negationCount { warnings.append(.negationMismatch) }
            if source.numbers != proposed.numbers { warnings.append(.numberMismatch) }
            if source.units != proposed.units
                || (source.numbers == proposed.numbers && source.measurements != proposed.measurements)
            {
                warnings.append(.unitMismatch)
            }
            if !source.containsLiteral(proposed) { warnings.append(.textChanged) }
        }

        let segment = sourceSegment(containing: sourceQuote, in: request.text)
        let context = DictationTextFacts(segment, locale: request.locale)
        if context.hasUncertaintyCue || hasNumericSelfCorrection(segment, locale: request.locale)
            || hasDiscourseCorrection(segment)
            || hasFollowingCorrection(after: sourceQuote, in: request.text)
            || (context.sides.count > 1 && context.sides != source.sides)
        {
            warnings.append(.ambiguousDictation)
        }
        switch fieldId {
        case .patientDateOfBirth:
            if dates(in: segment, locale: request.locale).count > 1 { warnings.append(.ambiguousDictation) }
        case .patientGender:
            if spokenGenders(context.tokens).count > 1 { warnings.append(.ambiguousDictation) }
        case .patientComplaints:
            // If ASR drops the boundary between complaints and findings, a
            // copied quote can still pass every literal-value check above.
            if sourceQuote.range(
                of: #"(?i)\b(?:ultrasound|узи|уз[а-я]{2,3}|(?:\d+|[а-яa-z]+)\s+(?:mm|мм|ml|мл|cm|см))\b"#,
                options: .regularExpression
            ) != nil {
                warnings.append(.ambiguousDictation)
            }
        case .examinationDescription:
            if DictationFollowingFieldCue.isInsideDescription(sourceQuote) {
                warnings.append(.ambiguousDictation)
            }
            if hasIncompleteObservationQuote(sourceQuote, in: request.text) {
                warnings.append(.ambiguousDictation)
            }
            if sourceQuote.range(
                of: #"(?i)\b(?:they\s+report|сообщает)\b"#,
                options: .regularExpression
            ) != nil,
                sourceQuote.range(
                    of: #"(?i)\b(?:ultrasound|узи)\b"#,
                    options: .regularExpression
                ) == nil
            {
                warnings.append(.ambiguousDictation)
            }
        case .examinationNumber, .patientName, .patientHeightCM, .patientWeightKG:
            break
        }
        return Array(Set(warnings)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func measurementWarnings(
        number: Double,
        source: DictationTextFacts,
        locale: Locale,
        conversions: [DictationUnit: Double]
    ) -> [VoiceProposalWarning] {
        let digitMeasurements = source.measurements.flatMap { unit, values -> [Double] in
            guard let factor = conversions[unit] else { return [] }
            return values.map { $0 * factor }
        }
        let spokenMeasurements = source.tokens.indices.compactMap { index -> Double? in
            guard let unit = DictationUnit.fromWord(source.tokens[index]),
                  let factor = conversions[unit], index > 0
            else { return nil }
            let largest = (1 ... min(4, index)).reversed().compactMap { count in
                SpokenCardinal.parse(source.tokens[index - count ..< index].joined(separator: " "), locale: locale)
            }.first
            return largest.map { Double($0) * factor }
        }
        let converted = digitMeasurements + spokenMeasurements
        var warnings: [VoiceProposalWarning] = []
        if converted.isEmpty {
            if source.numbers.contains(number) {
                warnings.append(.unitMismatch)
            } else {
                warnings.append(.numberMismatch)
                if source.units.isEmpty { warnings.append(.unitMismatch) }
            }
        } else if !converted.contains(where: { abs($0 - number) < 0.0001 }) {
            warnings.append(.numberMismatch)
        }
        if let first = converted.first, converted.contains(where: { abs($0 - first) > 0.0001 }) {
            warnings.append(.ambiguousDictation)
        }
        if !source.units.isSubset(of: Set(conversions.keys)) {
            warnings.append(.unitMismatch)
        }
        return warnings
    }

    private static func hasCitedIdentifier(_ identifier: String, in quote: String, locale: Locale) -> Bool {
        let numericPattern = #"(?<![\p{L}\p{N}])"# + DictationIdentifierCue.pattern
            + #"\s*[:№]?\s*([0-9]+)(?![\p{L}\p{N}])"#
        if let expression = try? NSRegularExpression(pattern: numericPattern, options: .caseInsensitive),
           let match = expression.firstMatch(in: quote, range: NSRange(quote.startIndex ..< quote.endIndex, in: quote)),
           let digits = Range(match.range(at: 1), in: quote).map({ String(quote[$0]) })
        {
            return digits == identifier
        }
        return hasSpokenIdentifier(identifier, in: quote, locale: locale)
    }

    private static func hasSpokenIdentifier(_ identifier: String, in quote: String, locale: Locale) -> Bool {
        let cue = DictationIdentifierCue.pattern
        guard let range = quote.range(of: cue, options: [.regularExpression, .caseInsensitive]) else { return false }
        let spoken = String(quote[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return SpokenDigitSequence.parse(spoken, locale: locale) == identifier
    }

    private static func spokenGenders(_ tokens: [String]) -> Set<VoiceGender> {
        var result = Set<VoiceGender>()
        for token in tokens {
            if token == "male" || token == "man" || token.hasPrefix("мужчин") || token.hasPrefix("мужск") {
                result.insert(.male)
            }
            if token == "female" || token == "woman" || token.hasPrefix("женщин") || token.hasPrefix("женск") {
                result.insert(.female)
            }
        }
        return result
    }

    private static func dates(in text: String, locale: Locale) -> Set<Date> {
        let pattern = #"(?<!\d)(?:\d{4}[-./]\d{1,2}[-./]\d{1,2}|\d{1,2}[-./]\d{1,2}[-./]\d{4})(?!\d)"#
        let formats = ["yyyy-MM-dd", "yyyy.MM.dd", "yyyy/MM/dd", "dd.MM.yyyy", "dd-MM-yyyy", "dd/MM/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false

        var result = Set<Date>()
        for literal in DictationTextFacts.matches(pattern, in: text) {
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: literal) {
                    result.insert(date)
                    break
                }
            }
        }
        // SpeechAnalyzer usually writes a spoken English date with its month
        // name. The parser can verify that form; the warning check must use the
        // same strict date parser rather than flagging every such date.
        let verbalPattern = #"\b(?:[\p{L}]+\s+\d{1,2},?\s+\d{4}|\d{1,2}\s+[\p{L}]+\s+\d{4}(?:\s+года)?)\b"#
        for literal in DictationTextFacts.matches(verbalPattern, in: text) {
            if let parsed = try? VoiceFieldValue.parse(fieldId: .patientDateOfBirth, text: literal, locale: locale),
               case let .date(date) = parsed
            {
                result.insert(date)
            }
        }
        if let spoken = DictationSpokenBirthDate.parse(text, locale: locale) {
            result.insert(spoken)
        }
        return result
    }

    private static func sourceSegment(containing quote: String, in text: String) -> String {
        if let segment = text.components(separatedBy: CharacterSet(charactersIn: ";\n"))
            .first(where: { $0.contains(quote) })
        {
            return segment
        }
        return quote
    }

    private static func hasNumericSelfCorrection(_ text: String, locale: Locale) -> Bool {
        let pattern = #"\d+(?:[.,]\d+)?\s*[,.;]?\s*(?:нет|no)\s*[,.;]?\s*\d+(?:[.,]\d+)?"#
        if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil { return true }

        // TTS and speech recognition often spell out measurements. A copied
        // quote such as "sixty five, no, sixty two millimeters" still needs
        // review even when the proposal repeats it byte for byte.
        let tokens = DictationTextFacts.matches(#"[\p{L}\p{N}]+"#, in: text.lowercased(with: locale))
        for index in tokens.indices where tokens[index] == "no" || tokens[index] == "нет" {
            guard index > 0, index + 1 < tokens.count else { continue }
            let preceding = (1 ... min(4, index)).contains { count in
                SpokenCardinal.parse(tokens[index - count ..< index].joined(separator: " "), locale: locale) != nil
            }
            let following = (1 ... min(4, tokens.count - index - 1)).contains { count in
                SpokenCardinal.parse(tokens[index + 1 ... index + count].joined(separator: " "), locale: locale) != nil
            }
            if preceding && following { return true }
        }
        return false
    }

    private static func hasIncompleteObservationQuote(_ quote: String, in text: String) -> Bool {
        guard let quoteRange = text.range(of: quote) else { return false }
        let observation = lastMatch(
            DictationObservationCue.pattern, in: text, before: quoteRange.upperBound
        )
        let complaint = lastMatch(DictationSectionCue.complaint, in: text, before: quoteRange.upperBound)
        if let complaint, complaint.lowerBound > (observation?.lowerBound ?? text.startIndex) {
            return true
        }
        guard let observation else { return false }

        // A literal model quote can omit the measured first sentence and cite
        // only the final negative sentence. Check the text between the finding
        // cue and the beginning of the quote, as well as the text after it.
        if observation.upperBound <= quoteRange.lowerBound {
            let omittedPrefix = text[observation.upperBound ..< quoteRange.lowerBound]
            if omittedPrefix.unicodeScalars.contains(where: {
                CharacterSet.letters.union(.decimalDigits).contains($0)
            }) {
                return true
            }
        }

        let suffix = String(text[quoteRange.upperBound...])
        let nextFieldCue = #"(?:"# + DictationFollowingFieldCue.recordPattern
            + #"|record\s+(?:marked|carries\s+number)|это\s+исследование\s+номер|"#
            + DictationSectionCue.complaint + #"|"# + DictationSectionCue.measurement + #")"#
        let remainingObservation = suffix.range(of: nextFieldCue, options: [.regularExpression, .caseInsensitive])
            .map { String(suffix[..<$0.lowerBound]) } ?? suffix
        return remainingObservation.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }

    private static func lastMatch(
        _ pattern: String, in text: String, before end: String.Index
    ) -> Range<String.Index>? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = expression.matches(in: text, range: NSRange(text.startIndex ..< end, in: text)).last
        else { return nil }
        return Range(match.range, in: text)
    }

    private static func hasDiscourseCorrection(_ text: String) -> Bool {
        let pattern = #"(?:^|[.;])\s*(?:нет|no)\s*[,—-]"#
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func hasFollowingCorrection(after quote: String, in text: String) -> Bool {
        let segments = text.components(separatedBy: CharacterSet(charactersIn: ";\n"))
        guard let index = segments.firstIndex(where: { $0.contains(quote) }), index + 1 < segments.count else {
            return false
        }
        let next = segments[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(?:(?:нет|no)\s*[,—-]|(?:но|but|вернее|точнее|поправка|actually|rather)\b)"#
        return next.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
