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
                guard !equivalent(
                    current.value,
                    candidate.value,
                    fieldId: candidate.id,
                    locale: request.locale,
                ) else {
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
                    let boundedComplaint: Bool = switch candidate.id {
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
                       (isExplicit && candidate.warnings.isEmpty) || boundedComplaint,
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

        let rejected = Set(
            (labeled?.rejectedFieldIds ?? []) + (generated?.rejectedFieldIds ?? []),
        )
        var seenFindings = Set<String>()
        let findings = ((labeled?.unmappedFindings ?? []) + (generated?.unmappedFindings ?? []))
            .filter { seenFindings.insert(
                $0,
            ).inserted }
        let source: DNeuralDictationProposalSource = if let generated {
            generated.source
        } else if labeled?.proposals.isEmpty == false {
            .labeledDictation
        } else {
            .explicitFacts
        }
        return DNeuralUltrasoundDictationProposal(
            source: source,
            proposals: request.allowedFields.compactMap { byId[
                $0,
            ] },
            unmappedFindings: findings,
            rejectedFieldIds: request.allowedFields.filter { rejected.contains(
                $0,
            ) && byId[
                $0,
            ] == nil },
            fieldSources: sources,
        )
    }

    private static func precedesFinding(
        _ quote: String,
        generated: DNeuralUltrasoundDictationProposal?,
        in text: String,
    ) -> Bool {
        guard let finding = generated?.proposals.first(
            where: { $0.id == .examinationDescription },
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
        locale: Locale,
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
            text.trimmingCharacters(
                in: .whitespacesAndNewlines.union(
                    .punctuationCharacters,
                ),
            )
            .split(
                whereSeparator: \.isWhitespace,
            ).joined(
                separator: " ",
            )
            .folding(
                options: .caseInsensitive,
                locale: locale,
            )
        }
        return normalized(
            firstText,
        ) == normalized(
            secondText,
        )
    }
}
