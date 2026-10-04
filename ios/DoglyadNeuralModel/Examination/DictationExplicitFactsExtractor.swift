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
        let identifierPattern = #"(?<![\p{L}\p{N}])"# + DictationIdentifierCue.pattern + #"\s+("#
            + digit + #"(?:(?:\s*,\s*|\s+)"# + digit + #"){0,7})(?![\p{L}\p{N}])(?!\s*,\s*[0-9])(?!\s*(?:mm|мм|cm|см|kg|кг|ml|мл)\b)"#
        if let match = uniqueMatch(identifierPattern, in: text),
           let identifier = identifier(match.value, locale: locale)
        {
            append(.examinationNumber, .text(identifier), quote: match.quote, to: &fields, request: request)
        }

        let namePatterns: [String]
        switch locale.language.languageCode?.identifier {
        case "en":
            namePatterns = [
                #"\bcase\s+\d+\s*:\s*([\p{L}]+\s+[\p{L}]+)\s+is\s+the\s+patient\b"#,
                #"\b(?:concerns|examining|regarding\s+patient)\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*[,.:]"#,
                #"\bpatient\s+details\s*:\s*([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,\s*(?:male|female)\b"#,
                #"\b(?:is\s+for|examined)\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,\s*(?:a\s+)?(?:male|female)\b"#,
                #"(?:^|[.;]\s*)for\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,?\s*born\b"#,
                #"\bpatient\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,\s*born\b"#,
                #"\bexamined\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*[.]\s*date\s+of\s+birth\b"#,
            ]
        case "ru":
            namePatterns = [
                #"\b(?:пациент|пациента|осматриваю|о\s+пациенте)\s+([\p{L}]+\s+[\p{L}]+)\s*[,.:]\s*(?:(?:пол\s+)?(?:мужчина|женщина)|дата\s+рождения)\b"#,
                #"\b(?:для|о\s+пациенте)\s+([\p{L}]+\s+[\p{L}]+)\s*[.]\s*пол\b"#,
                #"\bданные\s+пациента\s*:\s*([\p{L}]+\s+[\p{L}]+)\s*,\s*(?:мужчина|женщина)\b"#,
                #"\b(?:к\s+пациенту|осмотрен\s+пациент)\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,\s*(?:мужчина|женщина)\b"#,
                #"(?:^|[.;]\s*)на\s+при[её]ме\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,?\s*(?:(?=\d{8}\s+года\s+рождения)|(?=\b(?:один|два|ноль)\b)|(?=[\d\s.,–—-]{4,45}\bгода\s+рождения\b))"#,
                #"\bпациент\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*,\s*дата\s+рождения\b"#,
                #"\bосматриваем\s+([\p{L}]+(?:\s+[\p{L}]+){1,2})\s*[.]\s*родил(?:ся|ась)\b"#,
            ]
        default:
            namePatterns = []
        }
        if let match = firstUniqueMatch(namePatterns, in: text) {
            append(.patientName, .text(match.value), quote: match.quote, to: &fields, request: request)
        }

        let genderPatterns: [String]
        switch locale.language.languageCode?.identifier {
        case "en":
            genderPatterns = [
                #"\b(?:recorded\s+)?(?:sex|gender)\s+(?:is\s+)?(male|female)\b"#,
                #"\bpatient\s+details\s*:\s*[\p{L}]+\s+[\p{L}]+\s*,\s*(male|female)\b"#,
                #"\b(?:concerns|examining|regarding\s+patient)\s+[\p{L}]+\s+[\p{L}]+\s*[,.:]\s*(male|female)\b"#,
                #"\b(?:is\s+for|examined)\s+[\p{L}]+(?:\s+[\p{L}]+){1,2}\s*,\s*(?:a\s+)?(male|female)\b"#,
                #"recorded\s+sex\s+(?:is\s+)?(male|female)\b"#,
                #"\bborn\s+(?:19|20)\d{2}-\d{2}-\d{2}\s*,\s*is\s+(male|female)\b"#,
                #"\bdate\s+of\s+birth\s+(?:19|20)\d{2}-\d{2}-\d{2}\s*;\s*(male|female)\b"#,
            ]
        case "ru":
            genderPatterns = [
                #"\bпол\s+(?:указан\s+как\s+)?(мужчина|женщина)\b"#,
                #"\b(?:пациент|пациента|осматриваю|о\s+пациенте)\s+[\p{L}]+\s+[\p{L}]+\s*[,.:]\s*(мужчина|женщина)\b"#,
                #"\bданные\s+пациента\s*:\s*[\p{L}]+\s+[\p{L}]+\s*,\s*(мужчина|женщина)\b"#,
                #"\b(?:к\s+пациенту|осмотрен\s+пациент)\s+[\p{L}]+(?:\s+[\p{L}]+){1,2}\s*,\s*(мужчина|женщина)\b"#,
                #"года\s+рождения\s*,?\s*(мужчина|женщина)\b"#,
                #"\bпол\s+(мужчина|женщина)\b"#,
                #"\bродил(?:ся|ась)\s+(?:19|20)\d{2}-\d{2}-\d{2}\s*,\s*(мужчина|женщина)\b"#,
            ]
        default:
            genderPatterns = []
        }
        if let match = firstUniqueMatch(genderPatterns, in: text) {
            let gender: VoiceGender = match.value.lowercased(with: locale) == "male"
                || match.value.lowercased(with: locale) == "мужчина" ? .male : .female
            append(.patientGender, .gender(gender), quote: match.quote, to: &fields, request: request)
        }

        let datePattern: String
        switch locale.language.languageCode?.identifier {
        case "en": datePattern = #"born\s+(.+?)(?=[,.;]\s+(?:the\s+)?recorded\s+sex\b)"#
        case "ru": datePattern = #",\s+(.+?\s+года\s+рождения)\b"#
        default: datePattern = "(?!)"
        }
        let compactEnglishDate = locale.language.languageCode?.identifier == "en"
            ? uniqueMatch(#"\bborn\s+((?:19|20)\d{6})\b"#, in: text)
            : nil
        let compactRussianDate = locale.language.languageCode?.identifier == "ru"
            ? uniqueMatch(#"\b((?:19|20)\d{6}\s+года\s+рождения)\b"#, in: text)
            : nil
        let isoBirthPattern: String
        switch locale.language.languageCode?.identifier {
        case "en": isoBirthPattern = #"(?:\bborn(?:\s+on)?|\b(?:date\s+of\s+birth|birth\s+date)(?:\s+is)?)\s+((?:19|20)\d{2}-\d{2}-\d{2})\b"#
        case "ru": isoBirthPattern = #"(?:\bдата\s+рождения|\bродил(?:ся|ась))\s+((?:19|20)\d{2}-\d{2}-\d{2})\b"#
        default: isoBirthPattern = "(?!)"
        }
        if let match = compactEnglishDate ?? compactRussianDate ?? uniqueMatch(isoBirthPattern, in: text)
            ?? uniqueMatch(datePattern, in: text)
        {
            let quote = locale.language.languageCode?.identifier == "ru" ? match.value : match.quote
            if let date = date(match.value, quote: quote, locale: locale) {
                append(.patientDateOfBirth, .date(date), quote: quote, to: &fields, request: request)
            }
        }

        let cardinal = #"([\p{L}\p{N}-]+(?:\s+[\p{L}\p{N}-]+){0,3})"#
        let heightPattern = #"(?:they\s+are|(?:measured\s+)?height(?:\s+(?:is|of|comes\s+to))?|stature|patient\s+is|(?:измеренный\s+)?рост(?:\s+(?:составляет|равен))?)\s+"# + cardinal
            + #"\s+(?:cm|см|centimet(?:er|re)s?|сантиметр(?:а|ов)?)\b"#
        let tallPattern = #"\bat\s+"# + cardinal + #"\s+(?:cm|centimet(?:er|re)s?)\s+tall\b"#
        if let match = uniqueMatch(heightPattern, in: text) ?? uniqueMatch(tallPattern, in: text),
           let number = number(match.value, locale: locale)
        {
            append(.patientHeightCM, .number(number), quote: match.quote, to: &fields, request: request)
        }

        let weightPattern = #"(?:weighs?|(?:body\s+)?weight|body\s+mass|(?:their\s+)?measured\s+weight|вес(?:ит|\s+пациента)?|(?:измеренный|текущий)\s+вес|масса(?:\s+тела|\s+пациента)?|измеренная\s+масса\s+тела)\s+(?:(?:is|of|measures|comes\s+to|recorded\s+at|равен|составляет)\s+)?"# + cardinal
            + #"\s+(?:kg|кг|kilograms?|килограмм(?:а|ов)?)\b"#
        let inWeightPattern = #"\b(?:and\s+)?([0-9]+(?:[.,][0-9]+)?)\s+(?:kg|kilograms?)\s+in\s+weight\b"#
        if let match = uniqueMatch(weightPattern, in: text) ?? uniqueMatch(inWeightPattern, in: text),
           let number = number(match.value, locale: locale)
        {
            append(.patientWeightKG, .number(number), quote: match.quote, to: &fields, request: request)
        }

        let observationCue = DictationObservationCue.pattern
        let complaintCue = DictationSectionCue.complaint
        let measurementCue = DictationSectionCue.measurement
        let recordCue = DictationFollowingFieldCue.recordPattern
        let complaintPattern = complaintCue + #"\s*[:,—-]?\s+(.+?)(?=\s*(?:"#
            + observationCue + #"|ultrasound\b|"# + measurementCue + #"|"# + recordCue + #"|$))"#
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

        let observationPattern = observationCue + #"\s*[,.:]?\s*(.+?)(?=\s*(?:this\s+is\s+study|это\s+исследование\s+номер|"#
            + complaintCue + #"|"# + measurementCue + #"|"# + recordCue + #"|$))"#
        if let match = uniqueMatch(observationPattern, in: text) {
            let observed = match.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !observed.isEmpty {
                append(
                    .examinationDescription,
                    .text(DictationDescriptionNormalizer.normalize(observed, locale: locale)),
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
        // ASR can punctuate a dictated identifier as "0,1,1" or "0,25".
        // All digits are present next to an explicit study-number cue.
        if trimmed.range(of: #"^[0-9]+(?:\s*,\s*[0-9]+){1,2}$"#, options: .regularExpression) != nil {
            let digits = String(trimmed.filter(\.isNumber))
            if digits.count <= 4 { return digits }
        }
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

    private static func firstUniqueMatch(_ patterns: [String], in text: String) -> Match? {
        for pattern in patterns {
            if let match = uniqueMatch(pattern, in: text) { return match }
        }
        return nil
    }
}
