import Foundation

/// Keeps independently supported fields from every parser while exposing
/// disagreements to the physician instead of silently replacing a value.
enum DNeuralUltrasoundDictationProposalReconciler {
    static func reconcile(
        request: DNeuralUltrasoundDictationParseRequest,
        labeled: DNeuralUltrasoundDictationProposal?,
        explicit: [DNeuralUltrasoundVoiceFieldProposal],
        generated: DNeuralUltrasoundDictationProposal?,
    ) -> DNeuralUltrasoundDictationProposal {
        let localization = request.localization
        var byId: [DNeuralUltrasoundVoiceFieldId: DNeuralUltrasoundVoiceFieldProposal] = [:]
        var sources: [DNeuralUltrasoundVoiceFieldId: DNeuralDictationProposalSource] = [:]

        func insert(
            _ candidate: DNeuralUltrasoundVoiceFieldProposal,
            source: DNeuralDictationProposalSource,
        ) {
            guard request.allowedFields.contains(
                candidate.id,
            ) else { return }
            if let current = byId[
                candidate.id,
            ] {
                let isGenerated = switch source {
                case .localModel, .serverModel: true
                case .labeledDictation, .explicitFacts: false
                }
                let isClinical = switch candidate.id {
                case .patientComplaints, .examinationDescription: true
                case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth, .patientHeightCM, .patientWeightKG: false
                }
                if isGenerated, isClinical {
                    let isEquivalent = equivalent(
                        current.value,
                        candidate.value,
                        fieldId: candidate.id,
                        request: request,
                    )
                    var warnings = candidate.warnings
                    if !isEquivalent, !warnings.contains(
                        .textChanged,
                    ) {
                        warnings.append(
                            .textChanged,
                        )
                    }
                    if !isEquivalent, !warnings.contains(
                        .ambiguousDictation,
                    ) {
                        warnings.append(
                            .ambiguousDictation,
                        )
                    }
                    byId[
                        candidate.id,
                    ] = DNeuralUltrasoundVoiceFieldProposal(
                        id: candidate.id,
                        value: candidate.value,
                        sourceQuote: candidate.sourceQuote,
                        accuracy: warnings.isEmpty ? candidate.accuracy : .questionable,
                        warnings: warnings,
                    )
                    sources[
                        candidate.id,
                    ] = source
                    return
                }
                guard !equivalent(
                    current.value,
                    candidate.value,
                    fieldId: candidate.id,
                    request: request,
                ) else {
                    switch candidate.id {
                    case .patientComplaints, .examinationDescription:
                        // Deterministic sources may retain equivalent formatting.
                        if candidate.warnings.isEmpty,
                           case let .text(
                               formatted,
                           ) = candidate.value,
                           case let .text(
                               original,
                           ) = current.value,
                           formatted.count(
                               where: { ".,;:!?".contains(
                                   $0,
                               ) },
                           ) >= original.filter(
                               { ".,;:!?".contains(
                                   $0,
                               ) },
                           ).count
                        {
                            byId[
                                candidate.id,
                            ] = DNeuralUltrasoundVoiceFieldProposal(
                                id: current.id,
                                value: candidate.value,
                                sourceQuote: current.sourceQuote,
                                accuracy: current.accuracy,
                                warnings: current.warnings,
                            )
                        }
                    case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth, .patientHeightCM, .patientWeightKG:
                        break
                    }
                    return
                }
                var warnings = current.warnings
                if !warnings.contains(
                    .ambiguousDictation,
                ) {
                    warnings.append(
                        .ambiguousDictation,
                    )
                }
                let selected: DNeuralUltrasoundVoiceFieldProposal
                let isExplicit = switch source {
                case .explicitFacts: true
                case .labeledDictation, .localModel, .serverModel: false
                }
                switch candidate.id {
                case .patientComplaints, .examinationDescription:
                    // An undelimited label can swallow the next clinical
                    // section. Prefer a warning-free, explicitly bounded
                    // subquote, while still surfacing the disagreement.
                    let isComplaintBounded: Bool = switch candidate.id {
                    case .patientComplaints:
                        !DNeuralUltrasoundDictationTextFacts(
                            current.sourceQuote,
                            locale: request.locale,
                            localization: localization,
                        ).units.isEmpty
                            && DNeuralUltrasoundDictationTextFacts(
                                candidate.sourceQuote,
                                locale: request.locale,
                                localization: localization,
                            ).units.isEmpty
                            && precedesFinding(
                                candidate.sourceQuote,
                                generated: generated,
                                in: request.text,
                            )
                            && candidate.warnings.allSatisfy { warning in
                                switch warning {
                                case .ambiguousDictation: true
                                case .identifierMismatch, .textChanged, .genderUnverified, .dateUnverified,
                                     .numberMismatch, .unitMismatch, .sideMismatch, .negationMismatch: false
                                }
                            }
                    case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                         .patientHeightCM, .patientWeightKG, .examinationDescription: false
                    }
                    if !current.warnings.isEmpty,
                       (isExplicit && candidate.warnings.isEmpty) || isComplaintBounded,
                       current.sourceQuote.contains(
                           candidate.sourceQuote,
                       )
                    {
                        selected = candidate
                        sources[
                            candidate.id,
                        ] = source
                        warnings = candidate.warnings + [.ambiguousDictation]
                    } else {
                        selected = current
                    }
                case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
                     .patientHeightCM, .patientWeightKG:
                    selected = current
                }
                byId[
                    candidate.id,
                ] = DNeuralUltrasoundVoiceFieldProposal(
                    id: selected.id,
                    value: selected.value,
                    sourceQuote: selected.sourceQuote,
                    accuracy: .questionable,
                    warnings: warnings,
                )
            } else {
                byId[
                    candidate.id,
                ] = candidate
                sources[
                    candidate.id,
                ] = source
            }
        }

        for candidate in labeled?.proposals ?? [] {
            insert(
                candidate,
                source: .labeledDictation,
            )
        }
        for candidate in explicit {
            insert(
                candidate,
                source: .explicitFacts,
            )
        }
        if let generated {
            for candidate in generated.proposals {
                insert(
                    candidate,
                    source: generated.source,
                )
            }
        }

        let source: DNeuralDictationProposalSource = if let generated {
            generated.source
        } else if labeled?.proposals.isEmpty == false {
            .labeledDictation
        } else {
            .explicitFacts
        }
        return DNeuralUltrasoundDictationProposal(
            source: source,
            proposals: request.allowedFields.compactMap { id in
                guard let field = byId[
                    id,
                ] else { return nil }
                switch id {
                case .patientName:
                    guard case let .text(
                        name,
                    ) = field.value else { return field }
                    return DNeuralUltrasoundVoiceFieldProposal(
                        id: id,
                        value: .text(
                            DNeuralVoiceFieldValue.normalizedPatientName(
                                name,
                                locale: request.locale,
                            ),
                        ),
                        sourceQuote: field.sourceQuote,
                        accuracy: field.accuracy,
                        warnings: field.warnings,
                    )
                case .examinationNumber, .patientGender, .patientDateOfBirth, .patientHeightCM, .patientWeightKG, .patientComplaints, .examinationDescription:
                    return field
                }
            },
            fieldSources: sources,
        )
    }

    private static func precedesFinding(
        _ quote: String,
        generated: DNeuralUltrasoundDictationProposal?,
        in text: String,
    ) -> Bool {
        guard let finding = generated?.proposals.first(
            where: { $0.id.isExaminationDescription },
        ),
            let complaintRange = text.range(
                of: quote,
            ),
            let findingRange = text.range(
                of: finding.sourceQuote,
            ),
            complaintRange.upperBound <= findingRange.lowerBound
        else { return false }
        return text[
            complaintRange.upperBound ..< findingRange.lowerBound,
        ]
        .trimmingCharacters(
            in: .whitespacesAndNewlines.union(
                .punctuationCharacters,
            ),
        ).isEmpty
    }

    private static func equivalent(
        _ first: DNeuralVoiceFieldValue,
        _ second: DNeuralVoiceFieldValue,
        fieldId: DNeuralUltrasoundVoiceFieldId,
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> Bool {
        if first == second { return true }
        switch fieldId {
        case .examinationNumber: return false
        case .patientName, .patientGender, .patientDateOfBirth, .patientHeightCM,
             .patientWeightKG, .patientComplaints, .examinationDescription: break
        }
        guard case let .text(
            firstText,
        ) = first,
            case let .text(
                secondText,
            ) = second
        else { return false }
        func normalized(
            _ text: String,
        ) -> String {
            DNeuralUltrasoundDictationTextFacts.matches(
                #"[+-]?\d+(?:[.,]\d+)?|[^\W\d_]+|[<>≤≥±×/%]+"#,
                in: text.folding(
                    options: .caseInsensitive,
                    locale: request.locale,
                ),
            ).joined(
                separator: " ",
            )
        }
        return normalized(
            firstText,
        ) == normalized(
            secondText,
        )
    }
}
