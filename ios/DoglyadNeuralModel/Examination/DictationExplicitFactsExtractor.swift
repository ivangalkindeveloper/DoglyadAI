import Foundation

/// Recovers values whose type and meaning are stated next to a distinctive cue.
/// It does not infer a value from neighbouring prose or fill missing fields.
enum DictationExplicitFactsExtractor {
    private struct Match {
        let quote: String
        let value: String
    }

    static func extract(request: DictationParseRequest) -> [VoiceFieldProposal] {
        let text = request.text
        let locale = request.locale
        var fields: [VoiceFieldProposal] = []

        let digit = #"(?:[0-9]+|zero|one|two|three|four|five|six|seven|eight|nine|ноль|один|одна|два|две|три|четыре|пять|шесть|семь|восемь|девять)"#
        let identifierPattern = #"(?:this\s+is\s+study|study|examination\s+number|это\s+исследование\s+номер|номер\s+исследования)\s+("#
            + digit + #"(?:\s+"# + digit + #"){0,7})(?![\p{L}\p{N}])"#
        if let match = uniqueMatch(identifierPattern, in: text),
           let identifier = identifier(match.value, locale: locale)
        {
            append(.examinationNumber, .text(identifier), quote: match.quote, to: &fields, request: request)
        }

        let namePattern: String
        switch locale.language.languageCode?.identifier {
        case "en":
            namePattern = #"(?:^|[.;]\s*)for\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,?\s*born\b"#
        case "ru":
            namePattern = #"(?:^|[.;]\s*)на\s+при[её]ме\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,?\s*(?:(?=\d{8}\s+года\s+рождения)|(?=\b(?:один|два|ноль)\b))"#
        default:
            namePattern = "(?!)"
        }
        if let match = uniqueMatch(namePattern, in: text) {
            append(.patientName, .text(match.value), quote: match.quote, to: &fields, request: request)
        }

        let genderPattern: String
        switch locale.language.languageCode?.identifier {
        case "en":
            genderPattern = #"recorded\s+sex\s+(?:is\s+)?(male|female)\b"#
        case "ru":
            genderPattern = #"года\s+рождения\s*,?\s*(мужчина|женщина)\b"#
        default:
            genderPattern = "(?!)"
        }
        if let match = uniqueMatch(genderPattern, in: text) {
            let gender: VoiceGender = match.value.lowercased(with: locale) == "male"
                || match.value.lowercased(with: locale) == "мужчина" ? .male : .female
            append(.patientGender, .gender(gender), quote: match.quote, to: &fields, request: request)
        }

        let datePattern: String
        switch locale.language.languageCode?.identifier {
        case "en": datePattern = #"born\s+(.+?)(?=,\s+(?:the\s+)?recorded\s+sex\b)"#
        case "ru": datePattern = #",\s+(.+?\s+года\s+рождения)\b"#
        default: datePattern = "(?!)"
        }
        let compactRussianDate = locale.language.languageCode?.identifier == "ru"
            ? uniqueMatch(#"\b((?:19|20)\d{6}\s+года\s+рождения)\b"#, in: text)
            : nil
        if let match = compactRussianDate ?? uniqueMatch(datePattern, in: text) {
            let quote = locale.language.languageCode?.identifier == "ru" ? match.value : match.quote
            if let date = date(match.value, quote: quote, locale: locale) {
                append(.patientDateOfBirth, .date(date), quote: quote, to: &fields, request: request)
            }
        }

        let cardinal = #"([\p{L}\p{N}-]+(?:\s+[\p{L}\p{N}-]+){0,3})"#
        let heightPattern = #"(?:they\s+are|height|рост)\s+"# + cardinal
            + #"\s+(?:cm|см|centimet(?:er|re)s?|сантиметр(?:а|ов)?)\b"#
        if let match = uniqueMatch(heightPattern, in: text),
           let number = number(match.value, locale: locale)
        {
            append(.patientHeightCM, .number(number), quote: match.quote, to: &fields, request: request)
        }

        let weightPattern = #"(?:weigh|weight|вес)\s+"# + cardinal
            + #"\s+(?:kg|кг|kilograms?|килограмм(?:а|ов)?)\b"#
        if let match = uniqueMatch(weightPattern, in: text),
           let number = number(match.value, locale: locale)
        {
            append(.patientWeightKG, .number(number), quote: match.quote, to: &fields, request: request)
        }

        let complaintPattern = #"(?:they\s+report|сообщает\s*[:,-]?)\s+(.+?)(?=\s*(?:on\s+ultrasound|an\s+ultrasound|на\s+узи|and\s+weigh|,\s*вес\b|$))"#
        if let match = uniqueMatch(complaintPattern, in: text) {
            let complaint = match.value.trimmingCharacters(
                in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;"))
            )
            // ASR may erase "on ultrasound" / "на УЗИ". In that case the
            // remainder can contain the examination itself, not a complaint.
            // Leave the field untouched rather than copying a mixed section.
            let hasMissingBoundary = complaint.range(
                of: #"(?i)\b(?:ultrasound|на\s+уз[а-я]{1,3}|(?:\d+|[а-яa-z]+)\s+(?:mm|мм|ml|мл|cm|см)|additional\s+abnormality|изменени[а-я]+\s+не\s+выявлено)\b"#,
                options: .regularExpression
            ) != nil
            if !complaint.isEmpty, !hasMissingBoundary,
               complaint.split(whereSeparator: \.isWhitespace).count <= 12
            {
                append(.patientComplaints, .text(complaint), quote: match.quote, to: &fields, request: request)
            }
        }

        let observationPattern = #"(?:(?:on|an)\s+ultrasound|на\s+узи)\s*[,.:]?\s*(.+?)(?=\s*(?:this\s+is\s+study|это\s+исследование\s+номер|they\s+report|сообщает\s*[:,-]?)|$)"#
        if let match = uniqueMatch(observationPattern, in: text) {
            let observed = match.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !observed.isEmpty {
                append(
                    .examinationDescription,
                    .text(normalizedDescription(observed, locale: locale)),
                    quote: match.quote,
                    to: &fields,
                    request: request
                )
            }
        }
        return fields
    }

    private static func append(
        _ id: VoiceFieldId, _ value: VoiceFieldValue, quote: String,
        to fields: inout [VoiceFieldProposal], request: DictationParseRequest
    ) {
        guard request.allowedFields.contains(id) else { return }
        fields.append(VoiceFieldProposal(
            id: id,
            value: value,
            sourceQuote: quote,
            warnings: DictationProposalValidator.warnings(
                fieldId: id, value: value, sourceQuote: quote, request: request
            )
        ))
    }

    private static func identifier(_ text: String, locale: Locale) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil { return trimmed }
        return SpokenDigitSequence.parse(trimmed, locale: locale)
    }

    private static func number(_ text: String, locale: Locale) -> Double? {
        if let parsed = Double(text), parsed.isFinite, parsed > 0 { return parsed }
        return SpokenCardinal.parse(text, locale: locale).map(Double.init)
    }

    private static func date(_ text: String, quote: String, locale: Locale) -> Date? {
        if let spoken = DictationSpokenBirthDate.parse(quote, locale: locale) { return spoken }
        let literal = text.replacingOccurrences(
            of: #"(?i)\s+года\s+рождения\s*$"#, with: "", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let isoDate: String
        if literal.range(of: #"^(?:19|20)\d{6}$"#, options: .regularExpression) != nil {
            isoDate = "\(literal.prefix(4))-\(literal.dropFirst(4).prefix(2))-\(literal.suffix(2))"
        } else {
            isoDate = literal
        }
        guard let parsed = try? VoiceFieldValue.parse(fieldId: .patientDateOfBirth, text: isoDate, locale: locale),
              case let .date(date) = parsed
        else { return nil }
        return date
    }

    private static func normalizedDescription(_ text: String, locale: Locale) -> String {
        let corrected = DictationNumericCorrection.apply(to: text)
        let measurementPattern = #"(?:[:.,])\s*([\p{L}\p{N}-]+(?:\s+[\p{L}\p{N}-]+){0,3})\s+(millimeters?|millimetres?|mm|миллиметр(?:а|ов)?|мм|centimeters?\s+per\s+second|сантиметр(?:а|ов)?\s+в\s+секунду|millilit(?:er|re)s?|миллилитр(?:а|ов)?|ml|мл|cm/s|см/с)\b"#
        guard let match = uniqueMatch(measurementPattern, in: corrected),
              let measurement = number(match.value, locale: locale),
              measurement.rounded() == measurement,
              let unit = measurementUnit(in: match.quote, locale: locale)
        else { return corrected }
        return corrected.replacingOccurrences(
            of: match.quote,
            with: ": \(Int(measurement)) \(unit)"
        )
    }

    private static func measurementUnit(in text: String, locale: Locale) -> String? {
        let russian = locale.language.languageCode?.identifier == "ru"
        if text.range(of: #"(?i)(?:millimeters?|millimetres?|мм|миллиметр(?:а|ов)?)\b"#, options: .regularExpression) != nil {
            return russian ? "мм" : "mm"
        }
        if text.range(of: #"(?i)(?:centimeters?\s+per\s+second|сантиметр(?:а|ов)?\s+в\s+секунду|cm/s|см/с)\b"#, options: .regularExpression) != nil {
            return russian ? "см/с" : "cm/s"
        }
        if text.range(of: #"(?i)(?:millilit(?:er|re)s?|миллилитр(?:а|ов)?|ml|мл)\b"#, options: .regularExpression) != nil {
            return russian ? "мл" : "ml"
        }
        return nil
    }

    private static func uniqueMatch(_ pattern: String, in text: String) -> Match? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        else { return nil }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex ..< text.endIndex, in: text))
        guard matches.count == 1, let match = matches.first,
              let quoteRange = Range(match.range, in: text),
              let valueRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return Match(quote: String(text[quoteRange]), value: String(text[valueRange]))
    }
}
