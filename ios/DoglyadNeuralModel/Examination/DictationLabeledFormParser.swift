import Foundation

/// Parses the explicit field-by-field dictation format shown in the recording UI.
/// Every value comes from one contiguous part of the transcript. Free-form speech
/// is left to the local model.
enum DictationLabeledFormParser {
    private struct LabeledValue {
        let id: VoiceFieldId
        let quote: String
        let rawValue: String
        let recoveredWithoutLabel: Bool

        init(id: VoiceFieldId, quote: String, rawValue: String, recoveredWithoutLabel: Bool = false) {
            self.id = id
            self.quote = quote
            self.rawValue = rawValue
            self.recoveredWithoutLabel = recoveredWithoutLabel
        }
    }

    private static let labels: [(VoiceFieldId, String)] = [
        (.examinationNumber, #"(?:номер\s+исследования|examination\s+number)"#),
        (.patientName, #"(?:пациент|patient)"#),
        (.patientGender, #"(?:пол|gender)"#),
        (.patientDateOfBirth, #"(?:дата\s+рождения|date\s+of\s+birth)"#),
        (.patientHeightCM, #"(?:рост|height|(?:high|hi)(?=\s*[,.:]?\s*\d+(?:[.,]\d+)?\s*(?:cm|centimet(?:er|re)s?|m|met(?:er|re)s?)\b))"#),
        (.patientWeightKG, #"(?:вес|weight|(?:weigh|way)(?=\s*[,.:]?\s*\d+(?:[.,]\d+)?\s*(?:kg|kilograms?|g|grams?)\b))"#),
        (.patientComplaints, #"(?:жалоб[аы]|complaints?)"#),
        (.examinationDescription, #"(?:описани[еяю]\s+исследования|examination[\s,]+description)"#),
    ]

    static func parse(request: DictationParseRequest) -> DictationProposal? {
        if let delimited = parseDelimited(request: request) { return delimited }
        if let reordered = parseUndelimitedReordered(request: request) { return reordered }

        let text = request.text
        let wholeRange = NSRange(text.startIndex ..< text.endIndex, in: text)
        var found: [(id: VoiceFieldId, range: NSRange)] = []
        let complaintsStart = firstLabelStart(.patientComplaints, in: text)
        let descriptionStart = firstLabelStart(.examinationDescription, in: text)

        for (id, label) in labels {
            let pattern = #"(?<![\p{L}\p{N}])"# + label + #"(?![\p{L}\p{N}])"#
            guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return nil
            }
            let matches = expression.matches(in: text, range: wholeRange)
            guard let match = matches.first(where: { match in
                isAllowedLabel(id, match: match, source: text as NSString,
                               complaintsStart: complaintsStart, descriptionStart: descriptionStart)
            }) else { continue }
            found.append((id, match.range))
        }

        let source = text as NSString
        // A partial field-by-field dictation is still structured. Missing fields
        // produce no proposal and therefore cannot change their form values.
        // Unordered labels remain on the model path because their boundaries are
        // less reliable without explicit separators.
        guard let first = found.first,
              found.count >= 2 || (
                  !text.contains(";") && !text.contains("\n")
                      && hasExplicitSeparator(after: first.range, in: source)
              ),
              source.substring(to: first.range.location)
              .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).isEmpty
        else { return nil }
        for index in 1 ..< found.count {
            guard NSMaxRange(found[index - 1].range) < found[index].range.location else { return nil }
        }

        return makeProposal(values: labeledValues(from: found, source: source),
                            unmapped: [], preRejected: [], request: request)
    }

    private static func hasExplicitSeparator(after label: NSRange, in source: NSString) -> Bool {
        let suffix = source.substring(from: NSMaxRange(label))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return suffix.hasPrefix(":") || suffix.hasPrefix("：")
    }

    /// When punctuation disappears, a dictation that starts with the examination
    /// description can still be segmented by the remaining unique field labels.
    /// Repeated labels are refused, except "complaints no complaints".
    private static func parseUndelimitedReordered(request: DictationParseRequest) -> DictationProposal? {
        let text = request.text
        let source = text as NSString
        let wholeRange = NSRange(location: 0, length: source.length)
        var found: [(id: VoiceFieldId, range: NSRange)] = []
        let complaintsStart = firstLabelStart(.patientComplaints, in: text)
        let descriptionStart = firstLabelStart(.examinationDescription, in: text)

        for (id, label) in labels {
            let pattern = #"(?<![\p{L}\p{N}])"# + label + #"(?![\p{L}\p{N}])"#
            guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return nil
            }
            let matches = expression.matches(in: text, range: wholeRange).filter {
                isAllowedLabel(id, match: $0, source: source,
                               complaintsStart: complaintsStart, descriptionStart: descriptionStart)
            }
            guard let first = matches.first else { continue }
            if matches.count > 1 {
                guard id == .patientComplaints, matches.count == 2,
                      source.substring(with: NSRange(
                          location: NSMaxRange(first.range),
                          length: matches[1].range.location - NSMaxRange(first.range)
                      )).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased() == "no"
                else { return nil }
            }
            found.append((id, first.range))
        }

        found.sort { $0.range.location < $1.range.location }
        guard found.first?.id == .examinationDescription,
              source.substring(to: found[0].range.location)
              .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).isEmpty
        else { return nil }
        for index in 1 ..< found.count {
            guard NSMaxRange(found[index - 1].range) < found[index].range.location else { return nil }
        }
        return makeProposal(values: labeledValues(from: found, source: source),
                            unmapped: [], preRejected: [], request: request)
    }

    private static func firstLabelStart(_ id: VoiceFieldId, in text: String) -> Int? {
        guard let label = labels.first(where: { $0.0 == id })?.1,
              let expression = try? NSRegularExpression(pattern: #"(?<![\p{L}\p{N}])"# + label + #"(?![\p{L}\p{N}])"#, options: .caseInsensitive)
        else { return nil }
        return expression.firstMatch(in: text, range: NSRange(text.startIndex ..< text.endIndex, in: text))?.range.location
    }

    private static func isAllowedLabel(
        _ id: VoiceFieldId, match: NSTextCheckingResult, source: NSString,
        complaintsStart: Int?, descriptionStart: Int?
    ) -> Bool {
        if id == .patientComplaints {
            let prefix = source.substring(to: match.range.location)
            if prefix.range(of: #"\b(?:no|нет)\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                return false
            }
        }
        let word = source.substring(with: match.range).lowercased()
        let isAlias = switch id {
        case .patientHeightCM: ["high", "hi"].contains(word)
        case .patientWeightKG: ["weigh", "way"].contains(word)
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription: false
        }
        guard isAlias else { return true }
        guard let complaintsStart, let descriptionStart else { return false }
        if descriptionStart < complaintsStart { return match.range.location > complaintsStart }
        return match.range.location < complaintsStart
    }

    private static func labeledValues(
        from found: [(id: VoiceFieldId, range: NSRange)], source: NSString
    ) -> [LabeledValue] {
        found.indices.map { index in
            let label = found[index]
            let end = index + 1 < found.count ? found[index + 1].range.location : source.length
            let valueStart = NSMaxRange(label.range)
            let valueRange = NSRange(location: valueStart, length: end - valueStart)
            let quoteRange = NSRange(location: label.range.location, length: end - label.range.location)
            return LabeledValue(
                id: label.id,
                quote: source.substring(with: quoteRange).trimmingCharacters(in: .whitespacesAndNewlines),
                rawValue: source.substring(with: valueRange)
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":;,")))
            )
        }
    }

    /// Explicit separators let the physician dictate fields in any order, omit
    /// fields, and keep unrelated instructions outside the preceding value.
    private static func parseDelimited(request: DictationParseRequest) -> DictationProposal? {
        let parts = request.text.components(separatedBy: CharacterSet(charactersIn: ";\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count > 1 else { return nil }

        var values: [LabeledValue] = []
        var unmapped: [String] = []
        for part in parts {
            let source = part as NSString
            let range = NSRange(location: 0, length: source.length)
            var labeled: LabeledValue?
            for (id, label) in labels {
                let pattern = #"^"# + label + #"\s*[:：]\s*"#
                guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let match = expression.firstMatch(in: part, range: range)
                else { continue }
                labeled = LabeledValue(
                    id: id,
                    quote: part,
                    rawValue: source.substring(from: NSMaxRange(match.range))
                )
                break
            }
            if let labeled {
                values.append(labeled)
            } else {
                unmapped.append(part)
            }
        }

        // Unrecognized segments stay separate from a clearly labeled value.
        // If labels are too sparse, leave the whole utterance to the model.
        guard !values.isEmpty, values.count * 2 >= parts.count else { return nil }
        let counts = Dictionary(grouping: values, by: \.id).mapValues(\.count)
        var seenDuplicates = Set<VoiceFieldId>()
        let duplicates = values.map(\.id).filter {
            counts[$0, default: 0] > 1 && seenDuplicates.insert($0).inserted
        }
        let unique = values.filter { counts[$0.id] == 1 }
        return makeProposal(
            values: unique,
            unmapped: unmapped,
            preRejected: duplicates,
            request: request
        )
    }

    private static func makeProposal(
        values: [LabeledValue],
        unmapped: [String],
        preRejected: [VoiceFieldId],
        request: DictationParseRequest
    ) -> DictationProposal {
        var proposals: [VoiceFieldProposal] = []
        var rejected = preRejected
        for entry in recoveringUnlabeledGender(in: recoveringMisheardComplaintLabel(in: values)) {
            guard request.allowedFields.contains(entry.id) else { continue }
            var rawValue = entry.rawValue.trimmingCharacters(
                in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":;,"))
            )
            // Recognizers can render the pause after a field name as punctuation.
            // Remove only a leading separator; trailing punctuation may mark an
            // unfinished finding and must remain available to validation.
            rawValue = rawValue.replacingOccurrences(
                of: #"^[.?!–—]\s+"#, with: "", options: .regularExpression
            )
            if entry.id == .patientComplaints {
                // The recognizer sometimes emits a false start of the following
                // "examination description" label as a trailing "exam".
                rawValue = rawValue.replacingOccurrences(
                    of: #"\s*,?\s+exam\s*$"#,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
            }
            var recoveredMeasurementBoundary = false
            switch entry.id {
            case .patientHeightCM, .patientWeightKG:
                if let leading = leadingMeasurement(rawValue, for: entry.id) {
                    rawValue = leading
                    recoveredMeasurementBoundary = true
                }
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientComplaints, .examinationDescription:
                break
            }
            let correctedNumber: String
            switch entry.id {
            case .examinationDescription:
                correctedNumber = DictationNumericCorrection.apply(to: rawValue)
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientWeightKG, .patientComplaints:
                correctedNumber = rawValue
            }
            let hasNumericSelfCorrection = correctedNumber != rawValue
            switch entry.id {
            case .examinationDescription:
                rawValue = DictationDescriptionNormalizer.normalize(correctedNumber, locale: request.locale)
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientWeightKG, .patientComplaints:
                rawValue = correctedNumber
            }
            guard !isUnfinishedDescription(rawValue, for: entry.id),
                  !isUnresolvedDescription(rawValue, for: entry.id, locale: request.locale),
                  let value = parseValue(rawValue, for: entry.id, locale: request.locale)
            else {
                rejected.append(entry.id)
                continue
            }
            var warnings = DictationProposalValidator.warnings(
                fieldId: entry.id,
                value: value,
                sourceQuote: entry.quote,
                request: request
            )
            if hasNumericSelfCorrection, !warnings.contains(.ambiguousDictation) {
                warnings.append(.ambiguousDictation)
            }
            if isMeasurementAliasQuote(entry), !warnings.contains(.ambiguousDictation) {
                warnings.append(.ambiguousDictation)
            }
            if entry.recoveredWithoutLabel, !warnings.contains(.ambiguousDictation) {
                warnings.append(.ambiguousDictation)
            }
            if recoveredMeasurementBoundary, !warnings.contains(.ambiguousDictation) {
                warnings.append(.ambiguousDictation)
            }
            if entry.id == .examinationNumber,
               rawValue.range(of: #"[.,–—-]"#, options: .regularExpression) != nil,
               !warnings.contains(.ambiguousDictation)
            {
                warnings.append(.ambiguousDictation)
            }
            proposals.append(VoiceFieldProposal(
                id: entry.id,
                value: value,
                sourceQuote: entry.quote,
                warnings: warnings
            ))
        }
        return DictationProposal(
            source: .labeledDictation,
            proposals: proposals,
            unmappedFindings: unmapped,
            rejectedFieldIds: rejected
        )
    }

    /// In the guided format, ASR often hears the complaint label as "complete"
    /// or "complain". Recover the following words only between a measured
    /// weight and an explicit examination-description label. This is always
    /// reviewable because the original label was not recognized.
    private static func recoveringMisheardComplaintLabel(in values: [LabeledValue]) -> [LabeledValue] {
        let hasComplaint = values.contains { entry in
            switch entry.id {
            case .patientComplaints: true
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientWeightKG, .examinationDescription: false
            }
        }
        guard !hasComplaint else { return values }
        var result: [LabeledValue] = []
        for (index, entry) in values.enumerated() {
            result.append(entry)
            guard index + 1 < values.count else { continue }
            switch entry.id {
            case .patientWeightKG: break
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientComplaints, .examinationDescription: continue
            }
            switch values[index + 1].id {
            case .examinationDescription: break
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientWeightKG, .patientComplaints: continue
            }
            guard let unitPattern = measurementUnitPattern(for: .patientWeightKG) else { continue }
            let pattern = "^[0-9]+(?:[.,][0-9]+)?\\s*(?:\(unitPattern))\\s+(complete|complain)\\s+([\\p{L}][^0-9]*)$"
            guard let groups = captures(pattern, in: entry.rawValue), groups.count == 2 else { continue }
            let complaint = groups[1].trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard !complaint.isEmpty,
                  let cueRange = entry.rawValue.range(of: groups[0])
            else { continue }
            result.append(LabeledValue(
                id: .patientComplaints,
                quote: String(entry.rawValue[cueRange.lowerBound...]),
                rawValue: complaint,
                recoveredWithoutLabel: true
            ))
        }
        return result
    }

    /// Speech recognition can drop the short Russian label "пол" while keeping
    /// the explicit gender word between the patient and birth date. Recover only
    /// that position; the missing label is still reported for review.
    private static func recoveringUnlabeledGender(in values: [LabeledValue]) -> [LabeledValue] {
        guard !values.contains(where: { isGenderField($0.id) }) else { return values }
        var result: [LabeledValue] = []
        for index in values.indices {
            let entry = values[index]
            let nextId = index + 1 < values.count ? values[index + 1].id : nil
            guard isPatientDatePair(entry.id, nextId) else {
                result.append(entry)
                continue
            }
            let source = entry.rawValue as NSString
            let pattern = #"\s+(?:(?:по|пол)\s+)?(мужчина|женщина)\s*$"#
            guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = expression.firstMatch(in: entry.rawValue, range: NSRange(location: 0, length: source.length)),
                  match.range.location > 0
            else {
                result.append(entry)
                continue
            }
            let quote = entry.quote as NSString
            let rawRange = quote.range(of: entry.rawValue, options: .backwards)
            guard rawRange.location != NSNotFound else {
                result.append(entry)
                continue
            }
            let prefixLength = rawRange.location + match.range.location
            guard prefixLength > 0 else {
                result.append(entry)
                continue
            }
            result.append(LabeledValue(
                id: entry.id,
                quote: quote.substring(to: prefixLength),
                rawValue: source.substring(to: match.range.location)
            ))
            result.append(LabeledValue(
                id: .patientGender,
                quote: source.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines),
                rawValue: source.substring(with: match.range(at: 1)),
                recoveredWithoutLabel: true
            ))
        }
        return result
    }

    private static func isGenderField(_ id: VoiceFieldId) -> Bool {
        switch id {
        case .patientGender: true
        case .examinationNumber, .patientName, .patientDateOfBirth, .patientHeightCM,
             .patientWeightKG, .patientComplaints, .examinationDescription: false
        }
    }

    private static func isPatientDatePair(_ current: VoiceFieldId, _ next: VoiceFieldId?) -> Bool {
        switch current {
        case .patientName:
            switch next {
            case .some(.patientDateOfBirth): true
            case .some(.examinationNumber), .some(.patientName), .some(.patientGender),
                 .some(.patientHeightCM), .some(.patientWeightKG), .some(.patientComplaints),
                 .some(.examinationDescription), .none: false
            }
        case .patientDateOfBirth:
            switch next {
            case .some(.patientName): true
            case .some(.examinationNumber), .some(.patientGender), .some(.patientDateOfBirth),
                 .some(.patientHeightCM), .some(.patientWeightKG), .some(.patientComplaints),
                 .some(.examinationDescription), .none: false
            }
        case .examinationNumber, .patientGender, .patientHeightCM, .patientWeightKG,
             .patientComplaints, .examinationDescription:
            false
        }
    }

    private static func isMeasurementAliasQuote(_ entry: LabeledValue) -> Bool {
        let lower = entry.quote.lowercased()
        switch entry.id {
        case .patientHeightCM:
            return lower.range(of: #"^(?:high|hi)[\s,.:]"#, options: .regularExpression) != nil
        case .patientWeightKG:
            return lower.range(of: #"^(?:weigh|way)[\s,.:]"#, options: .regularExpression) != nil
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription: return false
        }
    }

    private static func isUnfinishedDescription(_ raw: String, for id: VoiceFieldId) -> Bool {
        guard id == .examinationDescription else { return false }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("...") || trimmed.hasSuffix("…") { return true }
        let words = trimmed.trimmingCharacters(in: .punctuationCharacters).lowercased()
        return words == "the measurement is" || words == "размер составляет"
    }

    private static func isUnresolvedDescription(_ raw: String, for id: VoiceFieldId, locale: Locale) -> Bool {
        guard id == .examinationDescription else { return false }
        let facts = DictationTextFacts(raw, locale: locale)
        if facts.hasUncertaintyCue { return true }
        let normalized = raw.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
        let sideCorrection = #"\b(?:but\s+(?:the\s+)?side\s+is|not\s+(?:left|right)|но\s+сторона|не\s+(?:слева|справа))\b"#
        return normalized.range(of: sideCorrection, options: .regularExpression) != nil
    }

    private static func parseValue(_ raw: String, for id: VoiceFieldId, locale: Locale) -> VoiceFieldValue? {
        switch id {
        case .examinationNumber:
            let number = raw.trimmingCharacters(in: .punctuationCharacters)
            if captures(#"^[0-9]{1,8}$"#, in: number) != nil { return .text(number) }
            if captures(#"^[0-9]+(?:[.,–—-][0-9]+)+$"#, in: number) != nil {
                let digits = String(number.filter(\.isNumber))
                if (1 ... 8).contains(digits.count) { return .text(digits) }
            }
            if let spokenDigits = SpokenDigitSequence.parse(number, locale: locale) {
                return .text(spokenDigits)
            }
            guard let groups = captures(#"^(?:ноль|zero)\s*([0-9]{1,7})$"#, in: number),
                  groups.count == 1
            else { return nil }
            return .text("0" + groups[0])
        case .patientName:
            let name = raw.trimmingCharacters(in: .punctuationCharacters)
            guard captures(#"^[\p{L}][\p{L}'’\-]*(?:\s+[\p{L}][\p{L}'’\-]*){0,3}$"#, in: name) != nil else {
                return nil
            }
            guard !VoiceGender.isIsolatedSpokenWord(name) else { return nil }
            return .text(name)
        case .patientGender:
            switch raw.trimmingCharacters(in: .punctuationCharacters).lowercased() {
            case "мужчина", "мужской", "male", "mail": return .gender(.male)
            case "женщина", "женский", "female": return .gender(.female)
            default: return nil
            }
        case .patientDateOfBirth:
            let dateText = raw.trimmingCharacters(in: .punctuationCharacters)
            if let value = try? VoiceFieldValue.parse(fieldId: id, text: dateText, locale: locale) {
                return value
            }
            if locale.language.languageCode?.identifier == "ru",
               let parts = captures(#"^([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{4})$"#, in: dateText),
               parts.count == 3,
               let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2])
            {
                let iso = String(format: "%04d-%02d-%02d", year, month, day)
                return try? VoiceFieldValue.parse(fieldId: id, text: iso, locale: locale)
            }
            // ASR may split a spoken year or merge it with a month. Reassemble
            // only when the full numeric utterance contains exactly eight digits.
            let digits: String
            if captures(#"^[0-9\s:,./-]+$"#, in: dateText) != nil {
                digits = String(dateText.filter(\.isNumber))
            } else if let spoken = SpokenDigitSequence.parse(dateText, locale: locale) {
                digits = spoken
            } else {
                return nil
            }
            guard digits.count == 8 else { return nil }
            let iso = "\(digits.prefix(4))-\(digits.dropFirst(4).prefix(2))-\(digits.suffix(2))"
            return try? VoiceFieldValue.parse(fieldId: id, text: iso, locale: locale)
        case .patientHeightCM, .patientWeightKG:
            return parseMeasurement(raw, for: id, locale: locale)
        case .patientComplaints, .examinationDescription:
            guard !raw.isEmpty else { return nil }
            return .text(raw)
        }
    }

    private static func parseMeasurement(_ raw: String, for id: VoiceFieldId, locale: Locale) -> VoiceFieldValue? {
        let measurementText = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard let unitPattern = measurementUnitPattern(for: id) else { return nil }
        let numericPattern = "^([0-9]+(?:[.,][0-9]+)?)\\s*(\(unitPattern))$"
        let spokenPattern = "^([\\p{L}]+(?:[\\s-]+[\\p{L}]+){0,3})\\s+(\(unitPattern))$"
        let groups = captures(numericPattern, in: measurementText)
            ?? captures(spokenPattern, in: measurementText)
        guard let groups, groups.count == 2,
              let amount = Double(groups[0].replacingOccurrences(of: ",", with: "."))
              ?? SpokenCardinal.parse(groups[0], locale: locale).map(Double.init),
              amount.isFinite, amount > 0
        else { return nil }
        let unit = groups[1].lowercased()
        let factor: Double
        switch id {
        case .patientHeightCM:
            factor = ["м", "m", "метр", "метра", "метров", "метры", "meter", "meters", "metre", "metres"]
                .contains(unit) ? 100 : 1
        case .patientWeightKG:
            factor = ["г", "g", "грамм", "грамма", "граммов", "граммы", "gram", "grams"]
                .contains(unit) ? 0.001 : 1
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription:
            return nil
        }
        return .number(amount * factor)
    }

    private static func measurementUnitPattern(for id: VoiceFieldId) -> String? {
        switch id {
        case .patientHeightCM:
            return #"см|cm|сантиметр(?:ов|а|ы)?|centimet(?:er|re)s?|м|m|метр(?:ов|а|ы)?|met(?:er|re)s?"#
        case .patientWeightKG:
            return #"кг|kg|килограмм(?:ов|а|ы)?|kilograms?|г|g|грамм(?:ов|а|ы)?|grams?"#
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription:
            return nil
        }
    }

    private static func leadingMeasurement(_ raw: String, for id: VoiceFieldId) -> String? {
        guard let unitPattern = measurementUnitPattern(for: id) else { return nil }
        let pattern = "^([0-9]+(?:[.,][0-9]+)?\\s*(?:\(unitPattern)))(?=\\s+[\\p{L}])"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = expression.firstMatch(in: raw, range: NSRange(raw.startIndex ..< raw.endIndex, in: raw)),
              let prefixRange = Range(match.range(at: 1), in: raw)
        else { return nil }
        let trailing = String(raw[prefixRange.upperBound...])
        guard trailing.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }
        return String(raw[prefixRange])
    }

    private static func captures(_ pattern: String, in text: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let wholeRange = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: wholeRange), match.range == wholeRange else {
            return nil
        }
        let source = text as NSString
        return (1 ..< match.numberOfRanges).map { source.substring(with: match.range(at: $0)) }
    }
}
