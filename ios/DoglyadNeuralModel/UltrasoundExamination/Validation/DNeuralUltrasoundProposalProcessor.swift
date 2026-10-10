import Foundation

/// Shares evidence validation and reconciliation between local and server models.
/// One instance holds the explicit fields for one dictation; it performs no I/O.
struct DNeuralUltrasoundProposalProcessor {
    private let request: DNeuralUltrasoundDictationParseRequest
    private let labeled: DNeuralUltrasoundDictationProposal?
    private let explicit: [DNeuralUltrasoundVoiceFieldProposal]

    init(
        request: DNeuralUltrasoundDictationParseRequest,
    ) {
        self.request = request
        labeled = DNeuralUltrasoundDictationLabeledFormParser.parse(
            request: request,
        )
        explicit = DNeuralUltrasoundDictationExplicitFactsExtractor.extract(
            request: request,
        )
    }

    var deterministic: DNeuralUltrasoundDictationProposal {
        reconcile(
            generated: nil,
        )
    }

    func process(
        generated: DNeuralUltrasoundProposalGenerationResponse,
        source: DNeuralDictationProposalSource,
        rejectedFieldIds: [DNeuralUltrasoundVoiceFieldId] = [],
    ) throws -> DNeuralUltrasoundDictationProposal {
        try reconcile(
            generated: Self.validate(
                generated: generated,
                request: request,
                source: source,
                rejectedFieldIds: rejectedFieldIds,
            ),
        )
    }

    private func reconcile(
        generated: DNeuralUltrasoundDictationProposal?,
    ) -> DNeuralUltrasoundDictationProposal {
        DNeuralUltrasoundDictationProposalReconciler.reconcile(
            request: request,
            labeled: labeled,
            explicit: explicit,
            generated: generated,
        )
    }

    static func validate(
        generated: DNeuralUltrasoundProposalGenerationResponse,
        request: DNeuralUltrasoundDictationParseRequest,
        source: DNeuralDictationProposalSource = .localModel,
        rejectedFieldIds: [DNeuralUltrasoundVoiceFieldId] = [],
    ) throws -> DNeuralUltrasoundDictationProposal {
        let localization = request.localization
        var seen = Set<DNeuralUltrasoundVoiceFieldId>()
        var verified: [DNeuralUltrasoundVoiceFieldProposal] = []
        var rejectedQuotes: [String] = []
        var rejected: [DNeuralUltrasoundVoiceFieldId] = []

        for item in DNeuralUltrasoundDictationClinicalSections.complete(
            generated.proposals,
            request: request,
        ) {
            guard request.allowedFields.contains(
                item.fieldId,
            ) else {
                throw DNeuralUltrasoundDictationProposalError.fieldNotAllowed(
                    item.fieldId,
                )
            }
            guard seen.insert(
                item.fieldId,
            ).inserted else {
                throw DNeuralUltrasoundDictationProposalError.duplicateField(
                    item.fieldId,
                )
            }
            guard let sourceQuote = Self.verbatimQuote(
                item.sourceQuote,
                in: request.text,
                locale: request.locale,
            ) else {
                rejected.append(
                    item.fieldId,
                )
                continue
            }
            let value: DNeuralVoiceFieldValue
            let correctedDate: Bool
            do {
                let generatedValue = try DNeuralVoiceFieldValue.parse(
                    fieldId: item.fieldId,
                    text: Self.normalizedValue(
                        item.value,
                        for: item.fieldId,
                        locale: request.locale,
                        localization: localization,
                    ),
                    locale: request.locale,
                    localization: localization,
                )
                if item.fieldId == .patientDateOfBirth,
                   case let .date(
                       generatedDate,
                   ) = generatedValue,
                   let spokenDate = DNeuralUltrasoundDictationSpokenBirthDate.parse(
                       sourceQuote,
                       locale: request.locale,
                       localization: localization,
                   )
                {
                    value = .date(
                        spokenDate,
                    )
                    correctedDate = spokenDate != generatedDate
                } else {
                    value = generatedValue
                    correctedDate = false
                }
            } catch DNeuralUltrasoundDictationProposalError.invalidValue {
                // Keep the other verified proposals usable. The rejected source
                // remains visible to the physician and cannot change the form.
                rejected.append(
                    item.fieldId,
                )
                rejectedQuotes.append(
                    sourceQuote,
                )
                continue
            }
            var warnings = DNeuralUltrasoundDictationProposalValidator.warnings(
                fieldId: item.fieldId,
                value: value,
                sourceQuote: sourceQuote,
                request: request,
            )
            if correctedDate, !warnings.contains(
                .ambiguousDictation,
            ) {
                warnings.append(
                    .ambiguousDictation,
                )
            }
            // A literal quote alone does not support a field. A model can cite
            // an unrelated passage and still invent a patient identity or a
            // measurement; do not offer such fields for confirmation.
            if Self.lacksFieldEvidence(
                fieldId: item.fieldId,
                value: value,
                warnings: warnings,
                sourceQuote: sourceQuote,
                request: request,
            ) {
                rejected.append(
                    item.fieldId,
                )
                rejectedQuotes.append(
                    sourceQuote,
                )
                continue
            }
            verified.append(
                DNeuralUltrasoundVoiceFieldProposal(
                    id: item.fieldId,
                    value: value,
                    sourceQuote: sourceQuote,
                    accuracy: item.accuracy,
                    warnings: warnings,
                ),
            )
        }

        var seenFindings = Set<String>()
        let unmappedFindings = (generated.unmappedFindings + rejectedQuotes).filter {
            !$0.trimmingCharacters(
                in: .whitespacesAndNewlines,
            ).isEmpty
                && request.text.contains(
                    $0,
                )
                && seenFindings.insert(
                    $0,
                ).inserted
        }
        return DNeuralUltrasoundDictationProposal(
            source: source,
            proposals: verified,
            unmappedFindings: unmappedFindings,
            rejectedFieldIds: (rejected + rejectedFieldIds).reduce(
                into: [],
            ) { result, id in
                if !result.contains(
                    id,
                ) { result.append(
                    id,
                ) }
            },
        )
    }

    private static func verbatimQuote(
        _ proposed: String,
        in text: String,
        locale: Locale,
    ) -> String? {
        guard !proposed.trimmingCharacters(
            in: .whitespacesAndNewlines,
        ).isEmpty else { return nil }
        if text.contains(
            proposed,
        ) { return proposed }
        // Generated evidence sometimes replaces a source comma with a final
        // period. Removing only terminal punctuation can recover a literal
        // quote; changing words or joining noncontiguous passages cannot.
        var literal = proposed.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        while let last = literal.last, ".,;:!?".contains(
            last,
        ) {
            literal.removeLast()
        }
        guard !literal.isEmpty,
              let range = text.range(
                  of: literal,
                  options: .caseInsensitive,
                  locale: locale,
              ),
              text.range(
                  of: literal,
                  options: .caseInsensitive,
                  range: range.upperBound ..< text.endIndex,
                  locale: locale,
              ) == nil
        else { return nil }
        return String(
            text[
                range,
            ],
        )
    }

    private static func normalizedValue(
        _ value: String,
        for fieldId: DNeuralUltrasoundVoiceFieldId,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        switch fieldId {
        case .examinationNumber:
            return DNeuralSpokenDigitSequence.parse(
                value,
                locale: locale,
                localization: localization.numbers,
            ) ?? value
        case .examinationDescription:
            let description = DNeuralUltrasoundDictationObservationCue.removeFraming(
                from: value,
                localization: localization,
            )
            return DNeuralUltrasoundDictationNumericCorrection.apply(
                to: description,
                localization: localization,
            )
        case .patientHeightCM, .patientWeightKG:
            return DNeuralSpokenCardinal.parse(
                value,
                locale: locale,
                localization: localization.numbers,
            ).map { String(
                $0,
            ) } ?? value
        case .patientComplaints:
            return value.replacingOccurrences(
                of: #"^\s*(?:"# + DNeuralUltrasoundDictationSectionCue.complaint(
                    localization: localization,
                ) + #")\s*[:,—-]?\s+"#,
                with: "",
                options: [.regularExpression, .caseInsensitive],
            )
        case .patientName, .patientGender, .patientDateOfBirth:
            return value
        }
    }

    private static func lacksFieldEvidence(
        fieldId: DNeuralUltrasoundVoiceFieldId,
        value: DNeuralVoiceFieldValue,
        warnings: [DNeuralVoiceProposalWarning],
        sourceQuote: String,
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> Bool {
        let localization = request.localization
        switch fieldId {
        case .examinationNumber:
            return warnings.contains(
                .identifierMismatch,
            )
        case .patientName:
            guard case let .text(
                name,
            ) = value else { return true }
            return warnings.contains(
                .textChanged,
            )
                || DNeuralVoiceGender.isIsolatedSpokenWord(
                    name,
                    localization: localization,
                )
                || !hasPatientCue(
                    before: name,
                    in: sourceQuote,
                    request: request,
                )
        case .patientGender:
            return warnings.contains(
                .genderUnverified,
            )
        case .patientDateOfBirth:
            guard warnings.contains(
                .dateUnverified,
            ) else { return false }
            return !DNeuralUltrasoundDictationTextFacts(
                sourceQuote,
                locale: request.locale,
                localization: localization,
            ).tokens.contains { token in
                localization.matches(
                    .birthEvidence,
                    token,
                )
            }
        case .patientHeightCM:
            return warnings.contains(
                .unitMismatch,
            )
                || !hasDirectCue(
                    in: sourceQuote,
                    request: request,
                    pattern: localization.pattern(
                        .directHeightCue,
                    ),
                )
        case .patientWeightKG:
            return warnings.contains(
                .unitMismatch,
            )
                || !hasDirectCue(
                    in: sourceQuote,
                    request: request,
                    pattern: localization.pattern(
                        .directWeightCue,
                    ),
                )
        case .examinationDescription:
            if DNeuralUltrasoundDictationProfileEvidence.containsOnlyProfile(
                sourceQuote,
                locale: request.locale,
                localization: localization,
            ) { return true }
            if isPatientIdentityQuote(
                sourceQuote,
                localization: localization,
            ) { return true }
            // Absence of complaints supplies no ultrasound finding. A model
            // must not duplicate that single fact into the description field.
            if sourceQuote.range(
                of: localization.pattern(
                    .absentComplaintQuote,
                ),
                options: .regularExpression,
            ) != nil { return true }
            // A complaint-only passage cannot become a second clinical field.
            return sourceQuote.range(
                of: #"^\s*(?:"# + DNeuralUltrasoundDictationSectionCue.complaint(
                    localization: localization,
                ) + #")"#,
                options: [.regularExpression, .caseInsensitive],
            ) != nil
                && sourceQuote.range(
                    of: DNeuralUltrasoundDictationObservationCue.pattern(
                        localization: localization,
                    ),
                    options: [.regularExpression, .caseInsensitive],
                ) == nil
                && DNeuralUltrasoundDictationTextFacts(
                    sourceQuote,
                    locale: request.locale,
                    localization: localization,
                ).units.isEmpty
        case .patientComplaints:
            if warnings.contains(
                .textChanged,
            ), case let .text(
                text,
            ) = value,
                text.range(
                    of: localization.pattern(
                        .unsupportedEmptyComplaint,
                    ),
                    options: .regularExpression,
                ) != nil { return true }
            let complaintCue = sourceQuote.range(
                of: DNeuralUltrasoundDictationSectionCue.complaint(
                    localization: localization,
                ),
                options: [.regularExpression, .caseInsensitive],
            )
            guard complaintCue == nil else { return false }
            if sourceQuote.range(
                of: #"^\s*(?:"# + DNeuralUltrasoundDictationObservationCue.pattern(
                    localization: localization,
                ) + #")"#,
                options: [.regularExpression, .caseInsensitive],
            ) != nil { return true }
            return isPatientIdentityQuote(
                sourceQuote,
                localization: localization,
            )
        }
    }

    private static func isPatientIdentityQuote(
        _ quote: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        quote.range(
            of: localization.pattern(
                .patientIdentityQuote,
            ),
            options: .regularExpression,
        ) != nil
    }

    private static func hasPatientCue(
        before name: String,
        in sourceQuote: String,
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> Bool {
        let localization = request.localization
        guard let quoteRange = request.text.range(
            of: sourceQuote,
        ),
            let nameRange = sourceQuote.range(
                of: name,
                options: .caseInsensitive,
                locale: request.locale,
            )
        else { return false }
        let precedingText = String(
            request.text[
                ..<quoteRange.lowerBound,
            ].suffix(
                40,
            ),
        )
        let beforeName = precedingText + String(
            sourceQuote[
                ..<nameRange.lowerBound,
            ],
        )
        let cue = localization.pattern(
            .patientNameCue,
        )
        return beforeName.range(
            of: cue,
            options: .regularExpression,
        ) != nil
    }

    private static func hasDirectCue(
        in quote: String,
        request: DNeuralUltrasoundDictationParseRequest,
        pattern: String,
    ) -> Bool {
        let localization = request.localization
        if quote.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive],
        ) != nil { return true }
        guard let range = request.text.range(
            of: quote,
        ),
            request.text.range(
                of: quote,
                range: range.upperBound ..< request.text.endIndex,
            ) == nil
        else { return false }
        // A model may quote only "94.2 kg". Accept the directly adjacent
        // "weight is" label, never a cue elsewhere in the dictation.
        let prefix = String(
            request.text[
                ..<range.lowerBound,
            ].suffix(
                60,
            ),
        )
        return prefix.range(
            of: pattern + localization.pattern(
                .directMeasurementSuffix,
            ),
            options: [.regularExpression, .caseInsensitive],
        ) != nil
    }
}
