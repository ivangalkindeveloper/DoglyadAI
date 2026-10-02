import Foundation

public struct DictationProposal: Sendable {
    public let source: DictationProposalSource
    public let proposals: [VoiceFieldProposal]
    public let unmappedFindings: [String]
    public let rejectedFieldIds: [VoiceFieldId]

    init(
        source: DictationProposalSource,
        proposals: [VoiceFieldProposal],
        unmappedFindings: [String],
        rejectedFieldIds: [VoiceFieldId]
    ) {
        self.source = source
        self.proposals = proposals
        self.unmappedFindings = unmappedFindings
        self.rejectedFieldIds = rejectedFieldIds
    }

    init(
        generated: DExaminationProposalGenerationResponse,
        request: DictationParseRequest,
        source: DictationProposalSource = .localModel
    ) throws {
        self.source = source
        var seen = Set<VoiceFieldId>()
        var verified: [VoiceFieldProposal] = []
        var rejectedQuotes: [String] = []
        var rejected: [VoiceFieldId] = []

        for item in generated.proposals {
            guard request.allowedFields.contains(item.fieldId) else {
                throw DictationProposalError.fieldNotAllowed(item.fieldId)
            }
            guard seen.insert(item.fieldId).inserted else {
                throw DictationProposalError.duplicateField(item.fieldId)
            }
            guard let sourceQuote = Self.verbatimQuote(item.sourceQuote, in: request.text, locale: request.locale) else {
                rejected.append(item.fieldId)
                continue
            }
            let value: VoiceFieldValue
            let correctedDate: Bool
            do {
                let generatedValue = try VoiceFieldValue.parse(
                    fieldId: item.fieldId,
                    text: Self.normalizedValue(item.value, for: item.fieldId, locale: request.locale),
                    locale: request.locale
                )
                if item.fieldId == .patientDateOfBirth,
                   case let .date(generatedDate) = generatedValue,
                   let spokenDate = DictationSpokenBirthDate.parse(sourceQuote, locale: request.locale)
                {
                    value = .date(spokenDate)
                    correctedDate = spokenDate != generatedDate
                } else {
                    value = generatedValue
                    correctedDate = false
                }
            } catch DictationProposalError.invalidValue {
                // Keep the other verified proposals usable. The rejected source
                // remains visible to the physician and cannot change the form.
                rejected.append(item.fieldId)
                rejectedQuotes.append(sourceQuote)
                continue
            }
            var warnings = DictationProposalValidator.warnings(
                fieldId: item.fieldId,
                value: value,
                sourceQuote: sourceQuote,
                request: request
            )
            if correctedDate, !warnings.contains(.ambiguousDictation) {
                warnings.append(.ambiguousDictation)
            }
            // A literal quote alone does not support a field. A model can cite
            // an unrelated passage and still invent a patient identity or a
            // measurement; do not offer such fields for confirmation.
            if Self.lacksFieldEvidence(fieldId: item.fieldId, warnings: warnings, sourceQuote: sourceQuote,
                                       locale: request.locale)
            {
                rejected.append(item.fieldId)
                rejectedQuotes.append(sourceQuote)
                continue
            }
            verified.append(VoiceFieldProposal(
                id: item.fieldId,
                value: value,
                sourceQuote: sourceQuote,
                warnings: warnings
            ))
        }

        proposals = verified
        rejectedFieldIds = rejected
        var seenFindings = Set<String>()
        unmappedFindings = (generated.unmappedFindings + rejectedQuotes).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && request.text.contains($0)
                && seenFindings.insert($0).inserted
        }
    }

    public init(serverResponse: USVoiceFormParseResponseDTO, request: DictationParseRequest) throws {
        let generated = DExaminationProposalGenerationResponse(
            proposals: serverResponse.proposals.map {
                DExaminationProposalGenerationItem(
                    fieldId: $0.fieldId,
                    value: $0.value,
                    sourceQuote: $0.sourceQuote
                )
            },
            unmappedFindings: serverResponse.unmappedFindings
        )
        let checked = try Self(generated: generated, request: request, source: .serverModel)
        self = Self(
            source: .serverModel,
            proposals: checked.proposals,
            unmappedFindings: checked.unmappedFindings,
            rejectedFieldIds: (checked.rejectedFieldIds + serverResponse.rejectedFieldIds).reduce(into: []) { result, id in
                if !result.contains(id) { result.append(id) }
            }
        )
    }

    private static func verbatimQuote(_ proposed: String, in text: String, locale: Locale) -> String? {
        guard !proposed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if text.contains(proposed) { return proposed }
        guard let range = text.range(of: proposed, options: .caseInsensitive, locale: locale),
              text.range(of: proposed, options: .caseInsensitive, range: range.upperBound ..< text.endIndex,
                         locale: locale) == nil
        else { return nil }
        return String(text[range])
    }

    private static func normalizedValue(_ value: String, for fieldId: VoiceFieldId, locale: Locale) -> String {
        switch fieldId {
        case .examinationNumber:
            return SpokenDigitSequence.parse(value, locale: locale) ?? value
        case .examinationDescription:
            let description = value.replacingOccurrences(
                of: #"(?i)^(?:on\s+ultrasound|(?:на\s+)?узи)\s*[,.:—-]?\s*"#,
                with: "",
                options: .regularExpression
            )
            return DictationNumericCorrection.apply(to: description)
        case .patientHeightCM, .patientWeightKG:
            return SpokenCardinal.parse(value, locale: locale).map { String($0) } ?? value
        case .patientName, .patientGender, .patientDateOfBirth, .patientComplaints:
            return value
        }
    }

    private static func lacksFieldEvidence(
        fieldId: VoiceFieldId, warnings: [VoiceProposalWarning], sourceQuote: String, locale: Locale
    ) -> Bool {
        switch fieldId {
        case .examinationNumber:
            return warnings.contains(.identifierMismatch)
        case .patientName:
            return warnings.contains(.textChanged)
        case .patientGender:
            return warnings.contains(.genderUnverified)
        case .patientDateOfBirth:
            guard warnings.contains(.dateUnverified) else { return false }
            return !DictationTextFacts(sourceQuote, locale: locale).tokens.contains { token in
                token == "born" || token == "birth" || token.hasPrefix("родил") || token.hasPrefix("рожд")
            }
        case .patientHeightCM, .patientWeightKG:
            return warnings.contains(.unitMismatch)
        case .patientComplaints, .examinationDescription:
            return false
        }
    }
}
