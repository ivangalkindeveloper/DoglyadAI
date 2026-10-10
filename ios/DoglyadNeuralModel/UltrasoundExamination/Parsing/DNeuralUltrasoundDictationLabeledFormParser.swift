import Foundation

/// Parses the explicit field-by-field dictation format shown in the recording UI.
/// Every value comes from one contiguous part of the transcript. Free-form speech
/// is left to the local model.
enum DNeuralUltrasoundDictationLabeledFormParser {
    private struct DNeuralUltrasoundLabeledValue {
        let id: DNeuralUltrasoundVoiceFieldId
        let quote: String
        let rawValue: String
        let recoveredWithoutLabel: Bool

        init(
            id: DNeuralUltrasoundVoiceFieldId,
            quote: String,
            rawValue: String,
            recoveredWithoutLabel: Bool = false,
        ) {
            self.id = id
            self.quote = quote
            self.rawValue = rawValue
            self.recoveredWithoutLabel = recoveredWithoutLabel
        }
    }

    private static func labels(
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> [(DNeuralUltrasoundVoiceFieldId, String)] {
        [
            (.examinationNumber, localization.pattern(
                .examinationNumberLabel,
            )),
            (.patientName, localization.pattern(
                .patientNameLabel,
            )),
            (.patientGender, localization.pattern(
                .patientGenderLabel,
            )),
            (.patientDateOfBirth, localization.pattern(
                .patientBirthDateLabel,
            )),
            (.patientHeightCM, localization.pattern(
                .patientHeightLabel,
            )),
            (.patientWeightKG, localization.pattern(
                .patientWeightLabel,
            )),
            (.patientComplaints, localization.pattern(
                .patientComplaintsLabel,
            )),
            (.examinationDescription, localization.pattern(
                .examinationDescriptionLabel,
            )),
        ]
    }

    static func parse(
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> DNeuralUltrasoundDictationProposal? {
        let localization = request.localization
        if let delimited = parseDelimited(
            request: request,
        ) { return delimited }
        if let reordered = parseUndelimitedReordered(
            request: request,
        ) { return reordered }

        let text = request.text
        let wholeRange = NSRange(
            text.startIndex ..< text.endIndex,
            in: text,
        )
        var found: [(id: DNeuralUltrasoundVoiceFieldId, range: NSRange)] = []
        let complaintsStart = firstLabelStart(
            .patientComplaints,
            in: text,
            localization: localization,
        )
        let descriptionStart = firstLabelStart(
            .examinationDescription,
            in: text,
            localization: localization,
        )

        for (id, label) in labels(
            localization: localization,
        ) {
            let pattern = #"(?<![\p{L}\p{N}])"# + label + #"(?![\p{L}\p{N}])"#
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive,
            ) else {
                return nil
            }
            let matches = expression.matches(
                in: text,
                range: wholeRange,
            )
            guard let match = matches.first(
                where: { match in
                    isAllowedLabel(
                        id,
                        match: match,
                        source: text as NSString,
                        complaintsStart: complaintsStart,
                        descriptionStart: descriptionStart,
                        localization: localization,
                    )
                },
            ) else { continue }
            found.append(
                (id, match.range),
            )
        }

        let source = text as NSString
        // A partial field-by-field dictation is still structured. Missing fields
        // produce no proposal and therefore cannot change their form values.
        // Unordered labels remain on the model path because their boundaries are
        // less reliable without explicit separators.
        guard let first = found.first,
              found.count >= 2 || (
                  !text.contains(
                      ";",
                  ) && !text.contains(
                      "\n",
                  )
                      && hasExplicitSeparator(
                          after: first.range,
                          in: source,
                      )
              ),
              source.substring(
                  to: first.range.location,
              )
              .trimmingCharacters(
                  in: .whitespacesAndNewlines.union(
                      .punctuationCharacters,
                  ),
              ).isEmpty
        else { return nil }
        for index in 1 ..< found.count {
            guard NSMaxRange(
                found[
                    index - 1,
                ].range,
            ) < found[
                index,
            ].range.location else { return nil }
        }

        return makeProposal(
            values: labeledValues(
                from: found,
                source: source,
            ),
            unmapped: [],
            preRejected: [],
            request: request,
        )
    }

    private static func hasExplicitSeparator(
        after label: NSRange,
        in source: NSString,
    ) -> Bool {
        let suffix = source.substring(
            from: NSMaxRange(
                label,
            ),
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        return suffix.range(
            of: #"^(?:[:：,，—–-]|\.(?=\s))"#,
            options: .regularExpression,
        ) != nil
    }

    /// When punctuation disappears, a dictation that starts with the examination
    /// description can still be segmented by the remaining unique field labels.
    /// Repeated labels are refused, except "complaints no complaints".
    private static func parseUndelimitedReordered(
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> DNeuralUltrasoundDictationProposal? {
        let localization = request.localization
        let text = request.text
        let source = text as NSString
        let wholeRange = NSRange(
            location: 0,
            length: source.length,
        )
        var found: [(id: DNeuralUltrasoundVoiceFieldId, range: NSRange)] = []
        let complaintsStart = firstLabelStart(
            .patientComplaints,
            in: text,
            localization: localization,
        )
        let descriptionStart = firstLabelStart(
            .examinationDescription,
            in: text,
            localization: localization,
        )

        for (id, label) in labels(
            localization: localization,
        ) {
            let pattern = #"(?<![\p{L}\p{N}])"# + label + #"(?![\p{L}\p{N}])"#
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive,
            ) else {
                return nil
            }
            let matches = expression.matches(
                in: text,
                range: wholeRange,
            ).filter {
                isAllowedLabel(
                    id,
                    match: $0,
                    source: source,
                    complaintsStart: complaintsStart,
                    descriptionStart: descriptionStart,
                    localization: localization,
                )
            }
            guard let first = matches.first else { continue }
            if matches.count > 1 {
                guard id == .patientComplaints, matches.count == 2,
                      source.substring(
                          with: NSRange(
                              location: NSMaxRange(
                                  first.range,
                              ),
                              length: matches[
                                  1,
                              ].range.location - NSMaxRange(
                                  first.range,
                              ),
                          ),
                      ).trimmingCharacters(
                          in: .whitespacesAndNewlines.union(
                              .punctuationCharacters,
                          ),
                      ).lowercased() == localization.negativeCorrectionWord
                else { return nil }
            }
            found.append(
                (id, first.range),
            )
        }

        found.sort { $0.range.location < $1.range.location }
        guard let first = found.first,
              first.id == .examinationDescription || found.allSatisfy(
                  { hasExplicitSeparator(
                      after: $0.range,
                      in: source,
                  ) },
              ),
              source.substring(
                  to: found[
                      0,
                  ].range.location,
              )
              .trimmingCharacters(
                  in: .whitespacesAndNewlines.union(
                      .punctuationCharacters,
                  ),
              ).isEmpty
        else { return nil }
        for index in 1 ..< found.count {
            guard NSMaxRange(
                found[
                    index - 1,
                ].range,
            ) < found[
                index,
            ].range.location else { return nil }
        }
        return makeProposal(
            values: labeledValues(
                from: found,
                source: source,
            ),
            unmapped: [],
            preRejected: [],
            request: request,
        )
    }

    private static func firstLabelStart(
        _ id: DNeuralUltrasoundVoiceFieldId,
        in text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Int? {
        guard let label = labels(
            localization: localization,
        ).first(
            where: { $0.0 == id },
        )?.1,
            let expression = try? NSRegularExpression(
                pattern: #"(?<![\p{L}\p{N}])"# + label + #"(?![\p{L}\p{N}])"#,
                options: .caseInsensitive,
            )
        else { return nil }
        return expression.firstMatch(
            in: text,
            range: NSRange(
                text.startIndex ..< text.endIndex,
                in: text,
            ),
        )?.range.location
    }

    private static func isAllowedLabel(
        _ id: DNeuralUltrasoundVoiceFieldId,
        match: NSTextCheckingResult,
        source: NSString,
        complaintsStart: Int?,
        descriptionStart: Int?,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        if id == .patientComplaints {
            let prefix = source.substring(
                to: match.range.location,
            )
            if prefix.range(
                of: localization.pattern(
                    .negativeLabelPrefix,
                ),
                options: [.regularExpression, .caseInsensitive],
            ) != nil {
                return false
            }
        }
        let word = source.substring(
            with: match.range,
        ).lowercased()
        let isAlias = switch id {
        case .patientHeightCM: localization.matches(
                .heightAlias,
                word,
            )
        case .patientWeightKG: localization.matches(
                .weightAlias,
                word,
            )
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription: false
        }
        guard isAlias else { return true }
        guard let complaintsStart, let descriptionStart else { return false }
        if descriptionStart < complaintsStart { return match.range.location > complaintsStart }
        return match.range.location < complaintsStart
    }

    private static func labeledValues(
        from found: [(id: DNeuralUltrasoundVoiceFieldId, range: NSRange)],
        source: NSString,
    ) -> [DNeuralUltrasoundLabeledValue] {
        found.indices.map { index in
            let label = found[
                index,
            ]
            let end = index + 1 < found.count ? found[
                index + 1,
            ].range.location : source.length
            let valueStart = NSMaxRange(
                label.range,
            )
            let valueRange = NSRange(
                location: valueStart,
                length: end - valueStart,
            )
            let quoteRange = NSRange(
                location: label.range.location,
                length: end - label.range.location,
            )
            return DNeuralUltrasoundLabeledValue(
                id: label.id,
                quote: source.substring(
                    with: quoteRange,
                ).trimmingCharacters(
                    in: .whitespacesAndNewlines,
                ),
                rawValue: source.substring(
                    with: valueRange,
                )
                .trimmingCharacters(
                    in: CharacterSet.whitespacesAndNewlines.union(
                        CharacterSet(
                            charactersIn: ":;,，",
                        ),
                    ),
                )
                .replacingOccurrences(
                    of: #"^[.—–-]\s+"#,
                    with: "",
                    options: .regularExpression,
                ),
            )
        }
    }

    /// Explicit separators let the physician dictate fields in any order, omit
    /// fields, and keep unrelated instructions outside the preceding value.
    private static func parseDelimited(
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> DNeuralUltrasoundDictationProposal? {
        let localization = request.localization
        let parts = request.text.components(
            separatedBy: CharacterSet(
                charactersIn: ";\n",
            ),
        )
        .map { $0.trimmingCharacters(
            in: .whitespacesAndNewlines,
        ) }
        .filter { !$0.isEmpty }
        guard parts.count > 1 else { return nil }

        var values: [DNeuralUltrasoundLabeledValue] = []
        var unmapped: [String] = []
        for part in parts {
            let source = part as NSString
            let range = NSRange(
                location: 0,
                length: source.length,
            )
            var labeled: DNeuralUltrasoundLabeledValue?
            for (id, label) in labels(
                localization: localization,
            ) {
                let pattern = #"^"# + label + #"\s*[:：]\s*"#
                guard let expression = try? NSRegularExpression(
                    pattern: pattern,
                    options: .caseInsensitive,
                ),
                    let match = expression.firstMatch(
                        in: part,
                        range: range,
                    )
                else { continue }
                labeled = DNeuralUltrasoundLabeledValue(
                    id: id,
                    quote: part,
                    rawValue: source.substring(
                        from: NSMaxRange(
                            match.range,
                        ),
                    ),
                )
                break
            }
            if let labeled {
                values.append(
                    labeled,
                )
            } else {
                unmapped.append(
                    part,
                )
            }
        }

        // Unrecognized segments stay separate from a clearly labeled value.
        // If labels are too sparse, leave the whole utterance to the model.
        guard !values.isEmpty, values.count * 2 >= parts.count else { return nil }
        let counts = Dictionary(
            grouping: values,
            by: \.id,
        ).mapValues(
            \.count,
        )
        var seenDuplicates = Set<DNeuralUltrasoundVoiceFieldId>()
        let duplicates = values.map(
            \.id,
        ).filter {
            counts[
                $0,
                default: 0,
            ] > 1 && seenDuplicates.insert(
                $0,
            ).inserted
        }
        let unique = values.filter { counts[
            $0.id,
        ] == 1 }
        return makeProposal(
            values: unique,
            unmapped: unmapped,
            preRejected: duplicates,
            request: request,
        )
    }

    private static func makeProposal(
        values: [DNeuralUltrasoundLabeledValue],
        unmapped: [String],
        preRejected: [DNeuralUltrasoundVoiceFieldId],
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> DNeuralUltrasoundDictationProposal {
        let localization = request.localization
        var proposals: [DNeuralUltrasoundVoiceFieldProposal] = []
        var rejected = preRejected
        for entry in recoveringUnlabeledGender(
            in: recoveringMisheardComplaintLabel(
                in: values,
                localization: localization,
            ),
            localization: localization,
        ) {
            guard request.allowedFields.contains(
                entry.id,
            ) else { continue }
            var rawValue = entry.rawValue.trimmingCharacters(
                in: .whitespacesAndNewlines.union(
                    CharacterSet(
                        charactersIn: ":;,",
                    ),
                ),
            )
            // Recognizers can render the pause after a field name as punctuation.
            // Remove only a leading separator; trailing punctuation may mark an
            // unfinished finding and must remain available to validation.
            rawValue = rawValue.replacingOccurrences(
                of: #"^[.?!–—]\s+"#,
                with: "",
                options: .regularExpression,
            )
            if entry.id == .patientComplaints {
                // The recognizer sometimes emits a false start of the following
                // "examination description" label as a trailing "exam".
                rawValue = rawValue.replacingOccurrences(
                    of: localization.pattern(
                        .trailingDescriptionFalseStart,
                    ),
                    with: "",
                    options: [.regularExpression, .caseInsensitive],
                )
            }
            var recoveredMeasurementBoundary = false
            switch entry.id {
            case .patientHeightCM, .patientWeightKG:
                if let leading = leadingMeasurement(
                    rawValue,
                    for: entry.id,
                    localization: localization,
                ) {
                    rawValue = leading
                    recoveredMeasurementBoundary = true
                }
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientComplaints, .examinationDescription:
                break
            }
            let correctedNumber: String = switch entry.id {
            case .examinationDescription:
                DNeuralUltrasoundDictationNumericCorrection.apply(
                    to: rawValue,
                    localization: localization,
                )
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientWeightKG, .patientComplaints:
                rawValue
            }
            let hasNumericSelfCorrection = correctedNumber != rawValue
            switch entry.id {
            case .examinationDescription:
                rawValue = DNeuralUltrasoundDictationDescriptionNormalizer.normalize(
                    correctedNumber,
                    locale: request.locale,
                    localization: localization,
                )
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientWeightKG, .patientComplaints:
                rawValue = correctedNumber
            }
            guard !isUnfinishedDescription(
                rawValue,
                for: entry.id,
                localization: localization,
            ),
                !isUnresolvedDescription(
                    rawValue,
                    for: entry.id,
                    locale: request.locale,
                    localization: localization,
                ),
                let value = parseValue(
                    rawValue,
                    for: entry.id,
                    locale: request.locale,
                    localization: localization,
                )
            else {
                rejected.append(
                    entry.id,
                )
                continue
            }
            var warnings = DNeuralUltrasoundDictationProposalValidator.warnings(
                fieldId: entry.id,
                value: value,
                sourceQuote: entry.quote,
                request: request,
            )
            switch entry.id {
            case .patientGender:
                if DNeuralUltrasoundDictationProposalValidator.hasFetalGenderEvidence(
                    entry.quote,
                    in: request.text,
                    localization: localization,
                ) {
                    rejected.append(
                        entry.id,
                    )
                    continue
                }
            case .examinationNumber, .patientName, .patientDateOfBirth, .patientHeightCM,
                 .patientWeightKG, .patientComplaints, .examinationDescription:
                break
            }
            if hasNumericSelfCorrection, !warnings.contains(
                .ambiguousDictation,
            ) {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if isMeasurementAliasQuote(
                entry,
                localization: localization,
            ), !warnings.contains(
                .ambiguousDictation,
            ) {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if entry.recoveredWithoutLabel, !warnings.contains(
                .ambiguousDictation,
            ) {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if recoveredMeasurementBoundary, !warnings.contains(
                .ambiguousDictation,
            ) {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            if entry.id == .examinationNumber,
               rawValue.range(
                   of: #"[.,–—-]"#,
                   options: .regularExpression,
               ) != nil,
               !warnings.contains(
                   .ambiguousDictation,
               )
            {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            proposals.append(
                DNeuralUltrasoundVoiceFieldProposal(
                    id: entry.id,
                    value: value,
                    sourceQuote: entry.quote,
                    warnings: warnings,
                ),
            )
        }
        return DNeuralUltrasoundDictationProposal(
            source: .labeledDictation,
            proposals: proposals,
            unmappedFindings: unmapped,
            rejectedFieldIds: rejected,
        )
    }

    /// In the guided format, ASR often hears the complaint label as "complete"
    /// or "complain". Recover the following words only between a measured
    /// weight and an explicit examination-description label. This is always
    /// reviewable because the original label was not recognized.
    private static func recoveringMisheardComplaintLabel(
        in values: [DNeuralUltrasoundLabeledValue],
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> [DNeuralUltrasoundLabeledValue] {
        let hasComplaint = values.contains { entry in
            switch entry.id {
            case .patientComplaints: true
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientWeightKG, .examinationDescription: false
            }
        }
        guard !hasComplaint else { return values }
        var result: [DNeuralUltrasoundLabeledValue] = []
        for (index, entry) in values.enumerated() {
            result.append(
                entry,
            )
            guard index + 1 < values.count else { continue }
            switch entry.id {
            case .patientWeightKG: break
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientComplaints, .examinationDescription: continue
            }
            switch values[
                index + 1,
            ].id {
            case .examinationDescription: break
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                 .patientHeightCM, .patientWeightKG, .patientComplaints: continue
            }
            guard let unitPattern = measurementUnitPattern(
                for: .patientWeightKG,
                localization: localization,
            ) else { continue }
            let pattern = "^[0-9]+(?:[.,][0-9]+)?\\s*(?:\(unitPattern))\\s+(\(localization.pattern(.complaintAlias)))\\s+([\\p{L}][^0-9]*)$"
            guard let groups = captures(
                pattern,
                in: entry.rawValue,
            ), groups.count == 2 else { continue }
            let complaint = groups[
                1,
            ].trimmingCharacters(
                in: .whitespacesAndNewlines.union(
                    .punctuationCharacters,
                ),
            )
            guard !complaint.isEmpty,
                  let cueRange = entry.rawValue.range(
                      of: groups[
                          0,
                      ],
                  )
            else { continue }
            result.append(
                DNeuralUltrasoundLabeledValue(
                    id: .patientComplaints,
                    quote: String(
                        entry.rawValue[
                            cueRange.lowerBound...,
                        ],
                    ),
                    rawValue: complaint,
                    recoveredWithoutLabel: true,
                ),
            )
        }
        return result
    }

    /// Speech recognition can drop the short Russian label "пол" while keeping
    /// the explicit gender word between the patient and birth date. Recover only
    /// that position; the missing label is still reported for review.
    private static func recoveringUnlabeledGender(
        in values: [DNeuralUltrasoundLabeledValue],
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> [DNeuralUltrasoundLabeledValue] {
        guard !values.contains(
            where: { isGenderField(
                $0.id,
            ) },
        ) else { return values }
        var result: [DNeuralUltrasoundLabeledValue] = []
        for index in values.indices {
            let entry = values[
                index,
            ]
            let nextId = index + 1 < values.count ? values[
                index + 1,
            ].id : nil
            guard isPatientDatePair(
                entry.id,
                nextId,
            ) else {
                result.append(
                    entry,
                )
                continue
            }
            let source = entry.rawValue as NSString
            let pattern = localization.pattern(
                .unlabeledGender,
            )
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive,
            ),
                let match = expression.firstMatch(
                    in: entry.rawValue,
                    range: NSRange(
                        location: 0,
                        length: source.length,
                    ),
                ),
                match.range.location > 0
            else {
                result.append(
                    entry,
                )
                continue
            }
            let quote = entry.quote as NSString
            let rawRange = quote.range(
                of: entry.rawValue,
                options: .backwards,
            )
            guard rawRange.location != NSNotFound else {
                result.append(
                    entry,
                )
                continue
            }
            let prefixLength = rawRange.location + match.range.location
            guard prefixLength > 0 else {
                result.append(
                    entry,
                )
                continue
            }
            result.append(
                DNeuralUltrasoundLabeledValue(
                    id: entry.id,
                    quote: quote.substring(
                        to: prefixLength,
                    ),
                    rawValue: source.substring(
                        to: match.range.location,
                    ),
                ),
            )
            result.append(
                DNeuralUltrasoundLabeledValue(
                    id: .patientGender,
                    quote: source.substring(
                        with: match.range,
                    ).trimmingCharacters(
                        in: .whitespacesAndNewlines,
                    ),
                    rawValue: source.substring(
                        with: match.range(
                            at: 1,
                        ),
                    ),
                    recoveredWithoutLabel: true,
                ),
            )
        }
        return result
    }

    private static func isGenderField(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) -> Bool {
        switch id {
        case .patientGender: true
        case .examinationNumber, .patientName, .patientDateOfBirth, .patientHeightCM,
             .patientWeightKG, .patientComplaints, .examinationDescription: false
        }
    }

    private static func isPatientDatePair(
        _ current: DNeuralUltrasoundVoiceFieldId,
        _ next: DNeuralUltrasoundVoiceFieldId?,
    ) -> Bool {
        switch current {
        case .patientName:
            switch next {
            case .some(
                .patientDateOfBirth,
            ): true
            case .some(
                .examinationNumber,
            ), .some(
                .patientName,
            ), .some(
                .patientGender,
            ),
            .some(
                .patientHeightCM,
            ), .some(
                .patientWeightKG,
            ), .some(
                .patientComplaints,
            ),
            .some(
                .examinationDescription,
            ), .none: false
            }
        case .patientDateOfBirth:
            switch next {
            case .some(
                .patientName,
            ): true
            case .some(
                .examinationNumber,
            ), .some(
                .patientGender,
            ), .some(
                .patientDateOfBirth,
            ),
            .some(
                .patientHeightCM,
            ), .some(
                .patientWeightKG,
            ), .some(
                .patientComplaints,
            ),
            .some(
                .examinationDescription,
            ), .none: false
            }
        case .examinationNumber, .patientGender, .patientHeightCM, .patientWeightKG,
             .patientComplaints, .examinationDescription:
            false
        }
    }

    private static func isMeasurementAliasQuote(
        _ entry: DNeuralUltrasoundLabeledValue,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        let lower = entry.quote.lowercased()
        switch entry.id {
        case .patientHeightCM:
            return lower.range(
                of: localization.pattern(
                    .heightAliasPrefix,
                ),
                options: .regularExpression,
            ) != nil
        case .patientWeightKG:
            return lower.range(
                of: localization.pattern(
                    .weightAliasPrefix,
                ),
                options: .regularExpression,
            ) != nil
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription: return false
        }
    }

    private static func isUnfinishedDescription(
        _ raw: String,
        for id: DNeuralUltrasoundVoiceFieldId,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        guard id == .examinationDescription else { return false }
        let trimmed = raw.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        if trimmed.hasSuffix(
            "...",
        ) || trimmed.hasSuffix(
            "…",
        ) { return true }
        let words = trimmed.trimmingCharacters(
            in: .punctuationCharacters,
        ).lowercased()
        return localization.matches(
            .unfinishedDescription,
            words,
        )
    }

    private static func isUnresolvedDescription(
        _ raw: String,
        for id: DNeuralUltrasoundVoiceFieldId,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        guard id == .examinationDescription else { return false }
        let facts = DNeuralUltrasoundDictationTextFacts(
            raw,
            locale: locale,
            localization: localization,
        )
        if facts.hasUncertaintyCue { return true }
        let normalized = raw.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale,
        )
        let sideCorrection = localization.pattern(
            .sideCorrection,
        )
        return normalized.range(
            of: sideCorrection,
            options: .regularExpression,
        ) != nil
    }

    private static func parseValue(
        _ raw: String,
        for id: DNeuralUltrasoundVoiceFieldId,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> DNeuralVoiceFieldValue? {
        switch id {
        case .examinationNumber:
            let number = raw.trimmingCharacters(
                in: .punctuationCharacters,
            )
            if captures(
                #"^[0-9]{1,8}$"#,
                in: number,
            ) != nil { return .text(
                number,
            ) }
            if captures(
                #"^[0-9]+(?:[.,–—-][0-9]+)+$"#,
                in: number,
            ) != nil {
                let digits = String(
                    number.filter(
                        \.isNumber,
                    ),
                )
                if (1 ... 8).contains(
                    digits.count,
                ) { return .text(
                    digits,
                ) }
            }
            if let spokenDigits = DNeuralSpokenDigitSequence.parse(
                number,
                locale: locale,
                localization: localization.numbers,
            ) {
                return .text(
                    spokenDigits,
                )
            }
            guard let groups = captures(
                localization.pattern(
                    .leadingSpokenZero,
                ),
                in: number,
            ),
                groups.count == 1
            else { return nil }
            return .text(
                "0" + groups[
                    0,
                ],
            )
        case .patientName:
            let name = raw.trimmingCharacters(
                in: .punctuationCharacters,
            )
            guard captures(
                #"^[\p{L}][\p{L}'’\-]*(?:\s+[\p{L}][\p{L}'’\-]*){0,3}$"#,
                in: name,
            ) != nil else {
                return nil
            }
            guard !DNeuralVoiceGender.isIsolatedSpokenWord(
                name,
                localization: localization,
            ) else { return nil }
            return .text(
                name,
            )
        case .patientGender:
            return DNeuralVoiceGender.fromSpokenWord(
                raw.trimmingCharacters(
                    in: .punctuationCharacters,
                ),
                localization: localization,
            ).map(
                DNeuralVoiceFieldValue.gender,
            )
        case .patientDateOfBirth:
            let dateText = raw.trimmingCharacters(
                in: .punctuationCharacters,
            )
            if let value = try? DNeuralVoiceFieldValue.parse(
                fieldId: id,
                text: dateText,
                locale: locale,
                localization: localization,
            ) {
                return value
            }
            if localization.usesDayFirstNumericDates,
               let parts = captures(
                   #"^([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{4})$"#,
                   in: dateText,
               ),
               parts.count == 3,
               let day = Int(
                   parts[
                       0,
                   ],
               ), let month = Int(
                   parts[
                       1,
                   ],
               ), let year = Int(
                   parts[
                       2,
                   ],
               )
            {
                let iso = String(
                    format: "%04d-%02d-%02d",
                    year,
                    month,
                    day,
                )
                return try? DNeuralVoiceFieldValue.parse(
                    fieldId: id,
                    text: iso,
                    locale: locale,
                    localization: localization,
                )
            }
            // ASR may split a spoken year or merge it with a month. Reassemble
            // only when the full numeric utterance contains exactly eight digits.
            let digits: String
            if captures(
                #"^[0-9\s:,./-]+$"#,
                in: dateText,
            ) != nil {
                digits = String(
                    dateText.filter(
                        \.isNumber,
                    ),
                )
            } else if let spoken = DNeuralSpokenDigitSequence.parse(
                dateText,
                locale: locale,
                localization: localization.numbers,
            ) {
                digits = spoken
            } else {
                return nil
            }
            guard digits.count == 8 else { return nil }
            let iso = "\(digits.prefix(4))-\(digits.dropFirst(4).prefix(2))-\(digits.suffix(2))"
            return try? DNeuralVoiceFieldValue.parse(
                fieldId: id,
                text: iso,
                locale: locale,
                localization: localization,
            )
        case .patientHeightCM, .patientWeightKG:
            return parseMeasurement(
                raw,
                for: id,
                locale: locale,
                localization: localization,
            )
        case .patientComplaints, .examinationDescription:
            guard !raw.isEmpty else { return nil }
            return .text(
                raw,
            )
        }
    }

    private static func parseMeasurement(
        _ raw: String,
        for id: DNeuralUltrasoundVoiceFieldId,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> DNeuralVoiceFieldValue? {
        let measurementText = raw.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        .replacingOccurrences(
            of: #"[\s.!?;,]+$"#,
            with: "",
            options: .regularExpression,
        )
        guard let unitPattern = measurementUnitPattern(
            for: id,
            localization: localization,
        ) else { return nil }
        let numericPattern = "^([0-9]+(?:[.,][0-9]+)?)\\s*(\(unitPattern))$"
        let spokenPattern = "^([\\p{L}]+(?:[\\s-]+[\\p{L}]+){0,3})\\s+(\(unitPattern))$"
        let groups = captures(
            numericPattern,
            in: measurementText,
        )
            ?? captures(
                spokenPattern,
                in: measurementText,
            )
        guard let groups, groups.count == 2,
              let amount = Double(
                  groups[
                      0,
                  ].replacingOccurrences(
                      of: ",",
                      with: ".",
                  ),
              )
              ?? DNeuralSpokenCardinal.parse(
                  groups[
                      0,
                  ],
                  locale: locale,
                  localization: localization.numbers,
              ).map(
                  Double.init,
              ),
              amount.isFinite, amount > 0
        else { return nil }
        let unit = groups[
            1,
        ].lowercased()
        let factor: Double
        switch id {
        case .patientHeightCM:
            factor = localization.matches(
                .meterValue,
                unit,
            ) ? 100 : 1
        case .patientWeightKG:
            factor = localization.matches(
                .gramValue,
                unit,
            ) ? 0.001 : 1
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription:
            return nil
        }
        return .number(
            amount * factor,
        )
    }

    private static func measurementUnitPattern(
        for id: DNeuralUltrasoundVoiceFieldId,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String? {
        switch id {
        case .patientHeightCM:
            localization.pattern(
                .heightUnits,
            )
        case .patientWeightKG:
            localization.pattern(
                .weightUnits,
            )
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription:
            nil
        }
    }

    private static func leadingMeasurement(
        _ raw: String,
        for id: DNeuralUltrasoundVoiceFieldId,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String? {
        guard let unitPattern = measurementUnitPattern(
            for: id,
            localization: localization,
        ) else { return nil }
        let pattern = "^([0-9]+(?:[.,][0-9]+)?\\s*(?:\(unitPattern)))(?=\\s+[\\p{L}])"
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive,
        ),
            let match = expression.firstMatch(
                in: raw,
                range: NSRange(
                    raw.startIndex ..< raw.endIndex,
                    in: raw,
                ),
            ),
            let prefixRange = Range(
                match.range(
                    at: 1,
                ),
                in: raw,
            )
        else { return nil }
        let trailing = String(
            raw[
                prefixRange.upperBound...,
            ],
        )
        guard trailing.rangeOfCharacter(
            from: .decimalDigits,
        ) == nil else { return nil }
        return String(
            raw[
                prefixRange,
            ],
        )
    }

    private static func captures(
        _ pattern: String,
        in text: String,
    ) -> [String]? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive,
        ) else { return nil }
        let wholeRange = NSRange(
            text.startIndex ..< text.endIndex,
            in: text,
        )
        guard let match = expression.firstMatch(
            in: text,
            range: wholeRange,
        ), match.range == wholeRange else {
            return nil
        }
        let source = text as NSString
        return (1 ..< match.numberOfRanges).map { source.substring(
            with: match.range(
                at: $0,
            ),
        ) }
    }
}
