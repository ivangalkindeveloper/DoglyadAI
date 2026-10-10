import Foundation

/// Flags explicit contradictions between a proposal and its dictated evidence.
/// An empty warning list does not establish acoustic or clinical equivalence.
/// The application also checks transcript provenance before automatic filling.
enum DNeuralUltrasoundDictationProposalValidator {
    static func warnings(
        fieldId: DNeuralUltrasoundVoiceFieldId,
        value: DNeuralVoiceFieldValue,
        sourceQuote: String,
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> [DNeuralVoiceProposalWarning] {
        let localization = request.localization
        let source = DNeuralUltrasoundDictationTextFacts(
            sourceQuote,
            locale: request.locale,
            localization: localization,
        )
        var warnings: [DNeuralVoiceProposalWarning] = []

        switch fieldId {
        case .examinationNumber:
            guard case let .text(
                number,
            ) = value else { return [.identifierMismatch] }
            if !hasCitedIdentifier(
                number,
                in: sourceQuote,
                locale: request.locale,
                localization: localization,
            ) {
                warnings.append(
                    .identifierMismatch,
                )
            }
        case .patientName:
            guard case let .text(
                name,
            ) = value else { return [.textChanged] }
            if !source.containsLiteral(
                DNeuralUltrasoundDictationTextFacts(
                    name,
                    locale: request.locale,
                    localization: localization,
                ),
            ) {
                warnings.append(
                    .textChanged,
                )
            }
        case .patientGender:
            guard case let .gender(
                gender,
            ) = value else { return [.genderUnverified] }
            let spoken = spokenGenders(
                source.tokens,
                localization: localization,
            )
            if spoken.count != 1 || !spoken.contains(
                gender,
            ) {
                warnings.append(
                    .genderUnverified,
                )
            }
        case .patientDateOfBirth:
            guard case let .date(
                date,
            ) = value else { return [.dateUnverified] }
            let spokenDates = dates(
                in: sourceQuote,
                locale: request.locale,
                localization: localization,
            )
            if !spokenDates.contains(
                date,
            ) { warnings.append(
                .dateUnverified,
            ) }
            if spokenDates.count > 1 { warnings.append(
                .ambiguousDictation,
            ) }
        case .patientHeightCM:
            guard case let .number(
                number,
            ) = value else { return [.numberMismatch] }
            warnings.append(
                contentsOf: measurementWarnings(
                    number: number,
                    source: DNeuralUltrasoundDictationTextFacts(
                        measurementEvidence(
                            in: sourceQuote,
                            fieldId: fieldId,
                            localization: localization,
                        ),
                        locale: request.locale,
                        localization: localization,
                    ),
                    locale: request.locale,
                    conversions: [.centimeter: 1, .meter: 100],
                    localization: localization,
                ),
            )
        case .patientWeightKG:
            guard case let .number(
                number,
            ) = value else { return [.numberMismatch] }
            warnings.append(
                contentsOf: measurementWarnings(
                    number: number,
                    source: DNeuralUltrasoundDictationTextFacts(
                        measurementEvidence(
                            in: sourceQuote,
                            fieldId: fieldId,
                            localization: localization,
                        ),
                        locale: request.locale,
                        localization: localization,
                    ),
                    locale: request.locale,
                    conversions: [.kilogram: 1, .gram: 0.001],
                    localization: localization,
                ),
            )
        case .patientComplaints, .examinationDescription:
            guard case let .text(
                text,
            ) = value else { return [.textChanged] }
            let proposed = DNeuralUltrasoundDictationTextFacts(
                text,
                locale: request.locale,
                localization: localization,
            )
            if source.sides != proposed.sides { warnings.append(
                .sideMismatch,
            ) }
            if source.negationCount != proposed.negationCount { warnings.append(
                .negationMismatch,
            ) }
            if source.numbers != proposed.numbers { warnings.append(
                .numberMismatch,
            ) }
            if source.units != proposed.units
                || (source.numbers == proposed.numbers && source.measurements != proposed.measurements)
            {
                warnings.append(
                    .unitMismatch,
                )
            }
            if !source.containsLiteral(
                proposed,
            ) { warnings.append(
                .textChanged,
            ) }
        }

        let segment = sourceSegment(
            containing: sourceQuote,
            in: request.text,
        )
        let context = DNeuralUltrasoundDictationTextFacts(
            segment,
            locale: request.locale,
            localization: localization,
        )
        if context.hasUncertaintyCue || hasNumericSelfCorrection(
            segment,
            locale: request.locale,
            localization: localization,
        )
            || hasDiscourseCorrection(
                segment,
                localization: localization,
            )
            || hasFollowingCorrection(
                after: sourceQuote,
                in: request.text,
                localization: localization,
            )
        {
            warnings.append(
                .ambiguousDictation,
            )
        }
        switch fieldId {
        case .patientDateOfBirth:
            if dates(
                in: segment,
                locale: request.locale,
                localization: localization,
            ).count > 1 { warnings.append(
                .ambiguousDictation,
            ) }
        case .patientGender:
            if isFetalGender(
                sourceQuote,
                in: segment,
                localization: localization,
            ) { warnings.append(
                .genderUnverified,
            ) }
            if spokenGenders(
                context.tokens,
                localization: localization,
            ).count > 1 { warnings.append(
                .ambiguousDictation,
            ) }
        case .patientComplaints:
            if context.sides.count > 1, context.sides != source.sides {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if hasIncompleteComplaintQuote(
                sourceQuote,
                in: request.text,
                localization: localization,
            ) {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            // If ASR drops the boundary between complaints and findings, a
            // copied quote can still pass every literal-value check above.
            if sourceQuote.range(
                of: localization.pattern(
                    .clinicalTextInComplaint,
                ),
                options: .regularExpression,
            ) != nil {
                warnings.append(
                    .ambiguousDictation,
                )
            }
        case .examinationDescription:
            if context.sides.count > 1, context.sides != source.sides {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if sourceQuote.range(
                of: DNeuralUltrasoundDictationSectionCue.complaint(
                    localization: localization,
                ),
                options: [.regularExpression, .caseInsensitive],
            ) != nil {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if DNeuralUltrasoundDictationFollowingFieldCue.isInsideDescription(
                sourceQuote,
                localization: localization,
            ) {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if hasIncompleteObservationQuote(
                sourceQuote,
                in: request.text,
                localization: localization,
            ) {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if sourceQuote.range(
                of: localization.pattern(
                    .reportCue,
                ),
                options: .regularExpression,
            ) != nil,
                sourceQuote.range(
                    of: localization.pattern(
                        .ultrasoundWord,
                    ),
                    options: .regularExpression,
                ) == nil
            {
                warnings.append(
                    .ambiguousDictation,
                )
            }
        case .examinationNumber, .patientName, .patientHeightCM, .patientWeightKG:
            break
        }
        return Array(
            Set(
                warnings,
            ),
        ).sorted { $0.rawValue < $1.rawValue }
    }

    private static func measurementWarnings(
        number: Double,
        source: DNeuralUltrasoundDictationTextFacts,
        locale: Locale,
        conversions: [DNeuralDictationUnit: Double],
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> [DNeuralVoiceProposalWarning] {
        let digitMeasurements = source.measurements.flatMap { unit, values -> [Double] in
            guard let factor = conversions[
                unit,
            ] else { return [] }
            return values.map { $0 * factor }
        }
        let spokenMeasurements = source.tokens.indices.compactMap { index -> Double? in
            guard let unit = DNeuralDictationUnit.fromWord(
                source.tokens[
                    index,
                ],
                localization: localization,
            ),
                let factor = conversions[
                    unit,
                ], index > 0
            else { return nil }
            let largest = (1 ... min(
                4,
                index,
            )).reversed().compactMap { count in
                DNeuralSpokenCardinal.parse(
                    source.tokens[
                        index - count ..< index,
                    ].joined(
                        separator: " ",
                    ),
                    locale: locale,
                    localization: localization.numbers,
                )
            }.first
            return largest.map { Double(
                $0,
            ) * factor }
        }
        let converted = digitMeasurements + spokenMeasurements
        var warnings: [DNeuralVoiceProposalWarning] = []
        if converted.isEmpty {
            if source.numbers.contains(
                number,
            ) {
                warnings.append(
                    .unitMismatch,
                )
            } else {
                warnings.append(
                    .numberMismatch,
                )
                if source.units.isEmpty { warnings.append(
                    .unitMismatch,
                ) }
            }
        } else if !converted.contains(
            where: { abs(
                $0 - number,
            ) < 0.0001 },
        ) {
            warnings.append(
                .numberMismatch,
            )
        }
        if let first = converted.first, converted.contains(
            where: { abs(
                $0 - first,
            ) > 0.0001 },
        ) {
            warnings.append(
                .ambiguousDictation,
            )
        }
        if !source.units.isSubset(
            of: Set(
                conversions.keys,
            ),
        ) {
            warnings.append(
                .unitMismatch,
            )
        }
        return warnings
    }

    private static func hasCitedIdentifier(
        _ identifier: String,
        in quote: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        let literalPattern = #"(?<![\p{L}\p{N}])"# + DNeuralUltrasoundDictationIdentifierCue.pattern(
            localization: localization,
        )
            + localization.pattern(
                .citedIdentifierPrefix,
            )
            + NSRegularExpression.escapedPattern(
                for: identifier,
            ) + #"(?![\p{L}\p{N}_/-])"#
        if identifier.range(
            of: #"^[\p{L}\p{N}]+(?:[-_/][\p{L}\p{N}]+)*$"#,
            options: .regularExpression,
        ) != nil,
            let range = quote.range(
                of: literalPattern,
                options: [.regularExpression, .caseInsensitive],
            )
        {
            let nextWord = DNeuralUltrasoundDictationTextFacts.matches(
                #"^\s*([\p{L}]+)"#,
                in: String(
                    quote[
                        range.upperBound...,
                    ],
                ),
            ).first?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines,
                ).lowercased(
                    with: locale,
                )
            return nextWord.flatMap { DNeuralDictationUnit.fromWord(
                $0,
                localization: localization,
            ) } == nil
        }
        return hasSpokenIdentifier(
            identifier,
            in: quote,
            locale: locale,
            localization: localization,
        )
    }

    private static func hasSpokenIdentifier(
        _ identifier: String,
        in quote: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        let cue = DNeuralUltrasoundDictationIdentifierCue.pattern(
            localization: localization,
        )
        guard let range = quote.range(
            of: cue,
            options: [.regularExpression, .caseInsensitive],
        ) else { return false }
        let spoken = String(
            quote[
                range.upperBound...,
            ],
        )
        .replacingOccurrences(
            of: localization.pattern(
                .spokenIdentifierPrefix,
            ),
            with: "",
            options: [.regularExpression, .caseInsensitive],
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        if spoken.range(
            of: #"^[0-9]+(?:\s*,\s*[0-9]+){1,2}$"#,
            options: .regularExpression,
        ) != nil {
            let digits = String(
                spoken.filter(
                    \.isNumber,
                ),
            )
            return digits.count <= 4 && digits == identifier
        }
        return DNeuralSpokenDigitSequence.parse(
            spoken,
            locale: locale,
            localization: localization.numbers,
        ) == identifier
    }

    private static func spokenGenders(
        _ tokens: [String],
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Set<DNeuralVoiceGender> {
        var result = Set<DNeuralVoiceGender>()
        for token in tokens {
            if localization.matches(
                .maleEvidence,
                token,
            ) { result.insert(
                .male,
            ) }
            if localization.matches(
                .femaleEvidence,
                token,
            ) { result.insert(
                .female,
            ) }
        }
        return result
    }

    private static func dates(
        in text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Set<Date> {
        let pattern = #"(?<!\d)(?:\d{4}[-./]\d{1,2}[-./]\d{1,2}|\d{1,2}[-./]\d{1,2}[-./]\d{4})(?!\d)"#
        let formats = ["yyyy-MM-dd", "yyyy.MM.dd", "yyyy/MM/dd", "dd.MM.yyyy", "dd-MM-yyyy", "dd/MM/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier: "en_US_POSIX",
        )
        formatter.timeZone = TimeZone(
            secondsFromGMT: 0,
        )
        formatter.calendar = Calendar(
            identifier: .gregorian,
        )
        formatter.isLenient = false

        var result = Set<Date>()
        for literal in DNeuralUltrasoundDictationTextFacts.matches(
            pattern,
            in: text,
        ) {
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(
                    from: literal,
                ) {
                    result.insert(
                        date,
                    )
                    break
                }
            }
        }
        // SpeechAnalyzer usually writes a spoken English date with its month
        // name. The parser can verify that form; the warning check must use the
        // same strict date parser rather than flagging every such date.
        let verbalPattern = localization.pattern(
            .verbalDate,
        )
        for literal in DNeuralUltrasoundDictationTextFacts.matches(
            verbalPattern,
            in: text,
        ) {
            if let parsed = try? DNeuralVoiceFieldValue.parse(
                fieldId: .patientDateOfBirth,
                text: literal,
                locale: locale,
                localization: localization,
            ),
                case let .date(
                    date,
                ) = parsed
            {
                result.insert(
                    date,
                )
            }
        }
        if let spoken = DNeuralUltrasoundDictationSpokenBirthDate.parse(
            text,
            locale: locale,
            localization: localization,
        ) {
            result.insert(
                spoken,
            )
        }
        return result
    }

    private static func sourceSegment(
        containing quote: String,
        in text: String,
    ) -> String {
        guard let quoteRange = text.range(
            of: quote,
        ),
            let expression = try? NSRegularExpression(
                pattern: #"[;\n]|[.!?](?=\s|$)"#,
            )
        else { return quote }
        let boundaries = expression.matches(
            in: text,
            range: NSRange(
                text.startIndex...,
                in: text,
            ),
        )
        .compactMap { Range(
            $0.range,
            in: text,
        ) }
        // A decimal or a date's internal dot is not a sentence boundary. A
        // multi-sentence quote retains all its sentences, but not the next field.
        let start = boundaries.last { $0.upperBound <= quoteRange.lowerBound }?.upperBound ?? text.startIndex
        let end = boundaries.first { $0.upperBound >= quoteRange.upperBound }?.upperBound ?? text.endIndex
        return String(
            text[
                start ..< end,
            ],
        )
    }

    static func hasFetalGenderEvidence(
        _ quote: String,
        in text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        isFetalGender(
            quote,
            in: sourceSegment(
                containing: quote,
                in: text,
            ),
            localization: localization,
        )
    }

    private static func isFetalGender(
        _ quote: String,
        in segment: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        guard let quoteRange = segment.range(
            of: quote,
        ) else { return false }
        let prefix = String(
            segment[
                ..<quoteRange.upperBound,
            ],
        )
        let fetal = lastMatch(
            localization.pattern(
                .fetalCue,
            ),
            in: prefix,
            before: prefix.endIndex,
        )
        let patient = lastMatch(
            localization.pattern(
                .motherCue,
            ),
            in: prefix,
            before: prefix.endIndex,
        )
        if let fetal {
            if let patient {
                if fetal.lowerBound > patient.lowerBound { return true }
            } else {
                return true
            }
        }
        let suffix = String(
            segment[
                quoteRange.upperBound...,
            ],
        )
        return suffix.range(
            of: localization.pattern(
                .followingFetalCue,
            ),
            options: [.regularExpression, .caseInsensitive],
        ) != nil
    }

    private static func measurementEvidence(
        in quote: String,
        fieldId: DNeuralUltrasoundVoiceFieldId,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        let cue: String
        switch fieldId {
        case .patientHeightCM: cue = localization.pattern(
                .heightEvidenceCue,
            )
        case .patientWeightKG: cue = localization.pattern(
                .weightEvidenceCue,
            )
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription: return quote
        }
        guard let start = quote.range(
            of: cue,
            options: [.regularExpression, .caseInsensitive],
        ) else { return quote }
        let suffix = String(
            quote[
                start.upperBound...,
            ],
        ).trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        .replacingOccurrences(
            of: #"^(?:[:：]\s*|[.,]\s+)"#,
            with: "",
            options: .regularExpression,
        )
        let nextField = localization.pattern(
            .followingMeasurementField,
        )
        let end = suffix.range(
            of: nextField,
            options: [.regularExpression, .caseInsensitive],
        )?.lowerBound ?? suffix.endIndex
        return String(
            quote[
                start,
            ],
        ) + " " + String(
            suffix[
                ..<end,
            ],
        )
    }

    private static func hasIncompleteComplaintQuote(
        _ quote: String,
        in text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        guard let range = text.range(
            of: quote,
        ) else { return false }
        let suffix = String(
            text[
                range.upperBound...,
            ],
        )
        let nextField = DNeuralUltrasoundDictationObservationCue.pattern(
            localization: localization,
        ) + #"|"# + DNeuralUltrasoundDictationFollowingFieldCue.recordPattern(
            localization: localization,
        )
            + #"|"# + DNeuralUltrasoundDictationFollowingFieldCue.patientPattern(
                localization: localization,
            ) + #"|"# + DNeuralUltrasoundDictationSectionCue.measurement(
                localization: localization,
            )
            + #"|"# + localization.pattern(
                .descriptionBoundary,
            )
        let end = suffix.range(
            of: nextField,
            options: [.regularExpression, .caseInsensitive],
        )?.lowerBound ?? suffix.endIndex
        return suffix[
            ..<end,
        ].unicodeScalars.contains { CharacterSet.letters.contains(
            $0,
        ) }
    }

    private static func hasNumericSelfCorrection(
        _ text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        let pattern = localization.pattern(
            .numericSelfCorrection,
        )
        if text.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive],
        ) != nil { return true }

        // TTS and speech recognition often spell out measurements. A copied
        // quote such as "sixty five, no, sixty two millimeters" still needs
        // review even when the proposal repeats it byte for byte.
        let tokens = DNeuralUltrasoundDictationTextFacts.matches(
            #"[\p{L}\p{N}]+"#,
            in: text.lowercased(
                with: locale,
            ),
        )
        for index in tokens.indices where tokens[
            index,
        ] == localization.negativeCorrectionWord {
            guard index > 0, index + 1 < tokens.count else { continue }
            let preceding = (1 ... min(
                4,
                index,
            )).contains { count in
                DNeuralSpokenCardinal.parse(
                    tokens[
                        index - count ..< index,
                    ].joined(
                        separator: " ",
                    ),
                    locale: locale,
                    localization: localization.numbers,
                ) != nil
            }
            let following = (1 ... min(
                4,
                tokens.count - index - 1,
            )).contains { count in
                DNeuralSpokenCardinal.parse(
                    tokens[
                        index + 1 ... index + count,
                    ].joined(
                        separator: " ",
                    ),
                    locale: locale,
                    localization: localization.numbers,
                ) != nil
            }
            if preceding, following { return true }
        }
        return false
    }

    private static func hasIncompleteObservationQuote(
        _ quote: String,
        in text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        guard let quoteRange = text.range(
            of: quote,
        ) else { return false }
        let observation = lastMatch(
            DNeuralUltrasoundDictationObservationCue.pattern(
                localization: localization,
            ),
            in: text,
            before: quoteRange.upperBound,
        )
        let complaint = lastMatch(
            DNeuralUltrasoundDictationSectionCue.complaint(
                localization: localization,
            ),
            in: text,
            before: quoteRange.upperBound,
        )
        if let complaint, complaint.lowerBound > (observation?.lowerBound ?? text.startIndex) {
            return true
        }
        guard let observation else { return false }

        // A literal model quote can omit the measured first sentence and cite
        // only the final negative sentence. Check the text between the finding
        // cue and the beginning of the quote, as well as the text after it.
        if observation.upperBound <= quoteRange.lowerBound {
            let omittedPrefix = text[
                observation.upperBound ..< quoteRange.lowerBound,
            ]
            if omittedPrefix.unicodeScalars.contains(
                where: {
                    CharacterSet.letters.union(
                        .decimalDigits,
                    ).contains(
                        $0,
                    )
                },
            ) {
                return true
            }
        }

        let suffix = String(
            text[
                quoteRange.upperBound...,
            ],
        )
        let nextFieldCue = #"(?:"# + DNeuralUltrasoundDictationFollowingFieldCue.recordPattern(
            localization: localization,
        )
            + #"|"# + localization.pattern(
                .followingRecordBoundary,
            ) + #"|"#
            + DNeuralUltrasoundDictationSectionCue.complaint(
                localization: localization,
            ) + #"|"# + DNeuralUltrasoundDictationSectionCue.measurement(
                localization: localization,
            )
            + #"|"# + DNeuralUltrasoundDictationFollowingFieldCue.patientPattern(
                localization: localization,
            ) + #")"#
        let remainingObservation = suffix.range(
            of: nextFieldCue,
            options: [.regularExpression, .caseInsensitive],
        )
        .map { String(
            suffix[
                ..<$0.lowerBound,
            ],
        ) } ?? suffix
        return remainingObservation.unicodeScalars.contains { CharacterSet.letters.contains(
            $0,
        ) }
    }

    private static func lastMatch(
        _ pattern: String,
        in text: String,
        before end: String.Index,
    ) -> Range<String.Index>? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive,
        ),
            let match = expression.matches(
                in: text,
                range: NSRange(
                    text.startIndex ..< end,
                    in: text,
                ),
            ).last
        else { return nil }
        return Range(
            match.range,
            in: text,
        )
    }

    private static func hasDiscourseCorrection(
        _ text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        let pattern = localization.pattern(
            .discourseCorrection,
        )
        return text.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive],
        ) != nil
    }

    private static func hasFollowingCorrection(
        after quote: String,
        in text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        guard let range = text.range(
            of: quote,
        ) else { return false }
        let next = String(
            text[
                range.upperBound...,
            ],
        )
        let pattern = localization.pattern(
            .followingCorrection,
        )
        return next.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive],
        ) != nil
    }
}
