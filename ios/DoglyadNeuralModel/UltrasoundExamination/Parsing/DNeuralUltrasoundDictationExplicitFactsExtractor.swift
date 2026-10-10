import Foundation

/// Recovers values whose type and meaning are stated next to a distinctive cue.
/// It does not infer a value from neighbouring prose or fill missing fields.
enum DNeuralUltrasoundDictationExplicitFactsExtractor {
    private struct DNeuralUltrasoundFactMatch {
        let quote: String
        let value: String
    }

    static func extract(
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> [DNeuralUltrasoundVoiceFieldProposal] {
        let localization = request.localization
        let text = request.text
        let locale = request.locale
        var fields: [DNeuralUltrasoundVoiceFieldProposal] = []
        let digit = localization.pattern(
            .identifierDigit,
        )
        let literalIdentifier = #"(?:[\p{L}]{1,8}[0-9]+|[\p{L}\p{N}]+(?:[-_/][\p{L}\p{N}]+)+)"#
        let identifierPattern = #"(?<![\p{L}\p{N}])"# + DNeuralUltrasoundDictationIdentifierCue.pattern(
            localization: localization,
        ) + localization.pattern(
            .identifierValuePrefix,
        ) + #"("#
            + literalIdentifier + #"|"# + digit + #"(?:(?:\s*,\s*|\s+)"# + digit + #"){0,7})"# + localization.pattern(
                .identifierValueSuffix,
            )
        if let match = uniqueMatch(
            identifierPattern,
            in: text,
        ),
            let identifier = identifier(
                match.value,
                locale: locale,
                localization: localization,
            ),
            let range = text.range(
                of: match.quote,
            )
        {
            let nextWord = DNeuralUltrasoundDictationTextFacts.matches(
                #"^\s*([\p{L}]+)"#,
                in: String(
                    text[
                        range.upperBound...,
                    ],
                ),
            ).first?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines,
                ).lowercased(
                    with: locale,
                )
            if nextWord.flatMap { DNeuralDictationUnit.fromWord(
                $0,
                localization: localization,
            ) } == nil {
                append(
                    .examinationNumber,
                    .text(
                        identifier,
                    ),
                    quote: match.quote,
                    to: &fields,
                    request: request,
                )
            }
        }

        let namePatterns = localization.namePatterns
        if let match = firstUniqueMatch(
            namePatterns,
            in: text,
        ) {
            append(
                .patientName,
                .text(
                    match.value,
                ),
                quote: match.quote,
                to: &fields,
                request: request,
            )
        }

        let genderPatterns = localization.genderPatterns
        if let match = firstUniqueMatch(
            genderPatterns,
            in: text,
        ) {
            guard let gender = DNeuralVoiceGender.fromSpokenWord(
                match.value,
                localization: localization,
            ) else { return fields }
            append(
                .patientGender,
                .gender(
                    gender,
                ),
                quote: match.quote,
                to: &fields,
                request: request,
            )
        }

        let datePattern = localization.pattern(
            .birthDateFact,
        )
        let compactDate = uniqueMatch(
            localization.pattern(
                .compactBirthFact,
            ),
            in: text,
        )
        let isoBirthPattern = localization.pattern(
            .isoBirthFact,
        )
        let namedBirthPattern = localization.pattern(
            .namedBirthFact,
        )
        if let match = compactDate ?? uniqueMatch(
            isoBirthPattern,
            in: text,
        )
            ?? uniqueMatch(
                namedBirthPattern,
                in: text,
            )
            ?? uniqueMatch(
                datePattern,
                in: text,
            )
        {
            let quote = localization.birthEvidenceUsesValue ? match.value : match.quote
            if let date = date(
                match.value,
                quote: quote,
                locale: locale,
                localization: localization,
            ) {
                append(
                    .patientDateOfBirth,
                    .date(
                        date,
                    ),
                    quote: quote,
                    to: &fields,
                    request: request,
                )
            }
        }

        let cardinal = #"([0-9]+(?:[.,][0-9]+)?|[\p{L}\p{N}-]+(?:\s+[\p{L}\p{N}-]+){0,3})"#
        let heightPattern = localization.pattern(
            .heightFactCue,
        ) + cardinal
            + localization.pattern(
                .heightFactUnits,
            )
        let tallPattern = localization.pattern(
            .tallFactCue,
        ) + cardinal + localization.pattern(
            .tallFactUnits,
        )
        if let match = uniqueMatch(
            heightPattern,
            in: text,
        ) ?? uniqueMatch(
            tallPattern,
            in: text,
        ),
            let number = number(
                match.value,
                locale: locale,
                localization: localization,
            )
        {
            append(
                .patientHeightCM,
                .number(
                    number,
                ),
                quote: match.quote,
                to: &fields,
                request: request,
            )
        }

        let weightPattern = localization.pattern(
            .weightFactCue,
        ) + cardinal
            + localization.pattern(
                .weightFactUnits,
            )
        let inWeightPattern = localization.pattern(
            .inWeightFact,
        )
        if let match = uniqueMatch(
            weightPattern,
            in: text,
        ) ?? uniqueMatch(
            inWeightPattern,
            in: text,
        ),
            let number = number(
                match.value,
                locale: locale,
                localization: localization,
            )
        {
            append(
                .patientWeightKG,
                .number(
                    number,
                ),
                quote: match.quote,
                to: &fields,
                request: request,
            )
        }

        let observationCue = DNeuralUltrasoundDictationObservationCue.pattern(
            localization: localization,
        )
        let complaintCue = DNeuralUltrasoundDictationSectionCue.complaint(
            localization: localization,
        )
        let measurementCue = DNeuralUltrasoundDictationSectionCue.measurement(
            localization: localization,
        )
        let recordCue = DNeuralUltrasoundDictationFollowingFieldCue.recordPattern(
            localization: localization,
        )
        let complaintPattern = complaintCue + #"\s*[:,—-]?\s+(.+?)(?=\s*(?:"#
            + observationCue + #"|"# + localization.pattern(
                .complaintObservationBoundary,
            ) + #"|"# + measurementCue + #"|"# + recordCue + #"|"#
            + DNeuralUltrasoundDictationFollowingFieldCue.patientPattern(
                localization: localization,
            ) + #"|$))"#
        if let match = uniqueMatch(
            complaintPattern,
            in: text,
        ) {
            let complaint = match.value.trimmingCharacters(
                in: .whitespacesAndNewlines.union(
                    CharacterSet(
                        charactersIn: ".,;",
                    ),
                ),
            )
            // ASR may erase "on ultrasound" / "на УЗИ". In that case the
            // remainder can contain the examination itself, not a complaint.
            // Leave the field untouched rather than copying a mixed section.
            let hasMissingBoundary = complaint.range(
                of: localization.pattern(
                    .missingComplaintBoundary,
                ),
                options: .regularExpression,
            ) != nil
            let hasExplicitEnd = text.range(
                of: observationCue,
                options: [.regularExpression, .caseInsensitive],
            ) != nil
            if !complaint.isEmpty, !hasMissingBoundary,
               hasExplicitEnd || complaint.split(
                   whereSeparator: \.isWhitespace,
               ).count <= 12
            {
                append(
                    .patientComplaints,
                    .text(
                        complaint,
                    ),
                    quote: match.quote,
                    to: &fields,
                    request: request,
                )
            }
        }
        if !fields.contains(
            where: { $0.id == .patientComplaints },
        ),
            let absence = uniqueMatch(
                localization.pattern(
                    .absentComplaintFact,
                ),
                in: text,
            )
        {
            append(
                .patientComplaints,
                .text(
                    absence.value,
                ),
                quote: absence.value,
                to: &fields,
                request: request,
            )
        }

        let observationPattern = observationCue + #"\s*[,.:]?\s*(.+?)(?=\s*(?:"# + localization.pattern(
            .observationValueBoundary,
        ) + #"|"#
            + complaintCue + #"|"# + measurementCue + #"|"# + recordCue + #"|"#
            + DNeuralUltrasoundDictationFollowingFieldCue.patientPattern(
                localization: localization,
            ) + #"|$))"#
        if let match = uniqueMatch(
            observationPattern,
            in: text,
        ) {
            let observed = match.value.trimmingCharacters(
                in: .whitespacesAndNewlines,
            )
            if !observed.isEmpty {
                append(
                    .examinationDescription,
                    .text(
                        DNeuralUltrasoundDictationDescriptionNormalizer.normalize(
                            observed,
                            locale: locale,
                            localization: localization,
                        ),
                    ),
                    quote: match.quote,
                    to: &fields,
                    request: request,
                )
            }
        }
        return fields
    }

    private static func append(
        _ id: DNeuralUltrasoundVoiceFieldId,
        _ value: DNeuralVoiceFieldValue,
        quote: String,
        to fields: inout [DNeuralUltrasoundVoiceFieldProposal],
        request: DNeuralUltrasoundDictationParseRequest,
    ) {
        guard request.allowedFields.contains(
            id,
        ) else { return }
        let warnings = DNeuralUltrasoundDictationProposalValidator.warnings(
            fieldId: id,
            value: value,
            sourceQuote: quote,
            request: request,
        )
        switch id {
        case .examinationNumber:
            guard !warnings.contains(
                .identifierMismatch,
            ) else { return }
        case .patientGender:
            guard !warnings.contains(
                .genderUnverified,
            ) else { return }
        case .patientName, .patientDateOfBirth, .patientHeightCM,
             .patientWeightKG, .patientComplaints, .examinationDescription:
            break
        }
        fields.append(
            DNeuralUltrasoundVoiceFieldProposal(
                id: id,
                value: value,
                sourceQuote: quote,
                warnings: warnings,
            ),
        )
    }

    private static func identifier(
        _ text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String? {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        if trimmed.range(
            of: #"^[0-9]+$"#,
            options: .regularExpression,
        ) != nil { return trimmed }
        if trimmed.contains(
            where: \.isNumber,
        ),
            trimmed.range(
                of: #"^[\p{L}\p{N}]+(?:[-_/][\p{L}\p{N}]+)*$"#,
                options: .regularExpression,
            ) != nil { return trimmed }
        // ASR can punctuate a dictated identifier as "0,1,1" or "0,25".
        // All digits are present next to an explicit study-number cue.
        if trimmed.range(
            of: #"^[0-9]+(?:\s*,\s*[0-9]+){1,2}$"#,
            options: .regularExpression,
        ) != nil {
            let digits = String(
                trimmed.filter(
                    \.isNumber,
                ),
            )
            if digits.count <= 4 { return digits }
        }
        return DNeuralSpokenDigitSequence.parse(
            trimmed,
            locale: locale,
            localization: localization.numbers,
        )
    }

    private static func number(
        _ text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Double? {
        if let parsed = Double(
            text.replacingOccurrences(
                of: ",",
                with: ".",
            ),
        ), parsed.isFinite, parsed > 0 { return parsed }
        return DNeuralSpokenCardinal.parse(
            text,
            locale: locale,
            localization: localization.numbers,
        ).map(
            Double.init,
        )
    }

    private static func date(
        _ text: String,
        quote: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Date? {
        if let spoken = DNeuralUltrasoundDictationSpokenBirthDate.parse(
            quote,
            locale: locale,
            localization: localization,
        ) { return spoken }
        let literal = text.replacingOccurrences(
            of: localization.pattern(
                .birthDateTrailingCue,
            ),
            with: "",
            options: .regularExpression,
        ).trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        let isoDate: String = if literal.range(
            of: #"^(?:19|20)\d{6}$"#,
            options: .regularExpression,
        ) != nil {
            "\(literal.prefix(4))-\(literal.dropFirst(4).prefix(2))-\(literal.suffix(2))"
        } else {
            literal
        }
        guard let parsed = try? DNeuralVoiceFieldValue.parse(
            fieldId: .patientDateOfBirth,
            text: isoDate,
            locale: locale,
            localization: localization,
        ),
            case let .date(
                date,
            ) = parsed
        else { return nil }
        return date
    }

    private static func uniqueMatch(
        _ pattern: String,
        in text: String,
    ) -> DNeuralUltrasoundFactMatch? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators],
        )
        else { return nil }
        let matches = expression.matches(
            in: text,
            range: NSRange(
                text.startIndex ..< text.endIndex,
                in: text,
            ),
        )
        guard matches.count == 1, let match = matches.first,
              let quoteRange = Range(
                  match.range,
                  in: text,
              ),
              let valueRange = Range(
                  match.range(
                      at: 1,
                  ),
                  in: text,
              )
        else { return nil }
        return DNeuralUltrasoundFactMatch(
            quote: String(
                text[
                    quoteRange,
                ],
            ),
            value: String(
                text[
                    valueRange,
                ],
            ),
        )
    }

    private static func firstUniqueMatch(
        _ patterns: [String],
        in text: String,
    ) -> DNeuralUltrasoundFactMatch? {
        for pattern in patterns {
            if let match = uniqueMatch(
                pattern,
                in: text,
            ) { return match }
        }
        return nil
    }
}
