import Foundation

/// Keeps independently supported fields from every parser while exposing
/// disagreements to the physician instead of silently replacing a value.
enum DictationProposalReconciler {
    static func reconcile(
        request: DictationParseRequest,
        labeled: DictationProposal?,
        explicit: [VoiceFieldProposal],
        generated: DictationProposal?
    ) -> DictationProposal {
        var byId: [VoiceFieldId: VoiceFieldProposal] = [:]
        var sources: [VoiceFieldId: DictationProposalSource] = [:]

        func insert(_ candidate: VoiceFieldProposal, source: DictationProposalSource) {
            guard request.allowedFields.contains(candidate.id) else { return }
            if let current = byId[candidate.id] {
                guard !equivalent(current.value, candidate.value, fieldId: candidate.id, locale: request.locale) else {
                    return
                }
                var warnings = current.warnings
                if !warnings.contains(.ambiguousDictation) {
                    warnings.append(.ambiguousDictation)
                }
                byId[candidate.id] = VoiceFieldProposal(
                    id: current.id, value: current.value,
                    sourceQuote: current.sourceQuote, accuracy: .questionable, warnings: warnings
                )
            } else {
                byId[candidate.id] = candidate
                sources[candidate.id] = source
            }
        }

        for candidate in labeled?.proposals ?? [] {
            insert(candidate, source: .labeledDictation)
        }
        for candidate in explicit {
            insert(candidate, source: .explicitFacts)
        }
        if let generated {
            for candidate in generated.proposals {
                insert(candidate, source: generated.source)
            }
        }

        let rejected = Set((labeled?.rejectedFieldIds ?? []) + (generated?.rejectedFieldIds ?? []))
        var seenFindings = Set<String>()
        let findings = ((labeled?.unmappedFindings ?? []) + (generated?.unmappedFindings ?? []))
            .filter { seenFindings.insert($0).inserted }
        let source: DictationProposalSource
        if let generated {
            source = generated.source
        } else if labeled?.proposals.isEmpty == false {
            source = .labeledDictation
        } else {
            source = .explicitFacts
        }
        return DictationProposal(
            source: source,
            proposals: request.allowedFields.compactMap { byId[$0] },
            unmappedFindings: findings,
            rejectedFieldIds: request.allowedFields.filter { rejected.contains($0) && byId[$0] == nil },
            fieldSources: sources
        )
    }

    private static func equivalent(
        _ first: VoiceFieldValue, _ second: VoiceFieldValue,
        fieldId: VoiceFieldId, locale: Locale
    ) -> Bool {
        if first == second { return true }
        switch fieldId {
        case .examinationNumber: return false
        case .patientName, .patientGender, .patientDateOfBirth, .patientHeightCM,
             .patientWeightKG, .patientComplaints, .examinationDescription: break
        }
        guard case let .text(firstText) = first,
              case let .text(secondText) = second
        else { return false }
        func normalized(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                .folding(options: .caseInsensitive, locale: locale)
        }
        return normalized(firstText) == normalized(secondText)
    }
}
