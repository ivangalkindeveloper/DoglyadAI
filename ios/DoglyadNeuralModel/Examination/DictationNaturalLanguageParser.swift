import Foundation
import NaturalLanguage

/// Diagnostic candidate: existing literal extraction plus Apple's person-name
/// tagging. The framework identifies a possible name; a nearby patient cue and
/// a verbatim quote are still required before proposing a form value.
enum DictationNaturalLanguageParser {
    static func parse(request: DictationParseRequest) -> DictationProposal {
        let labeled = DictationLabeledFormParser.parse(request: request)
        let explicit = DictationExplicitFactsExtractor.extract(request: request)
        let baseline = DictationProposalReconciler.reconcile(
            request: request, labeled: labeled, explicit: explicit, generated: nil
        )
        guard !baseline.proposals.contains(where: { $0.id == .patientName }),
              !baseline.rejectedFieldIds.contains(.patientName),
              request.allowedFields.contains(.patientName),
              let name = patientName(in: request)
        else { return baseline }

        let naturalLanguage = DictationProposal(
            source: .explicitFacts, proposals: [name], unmappedFindings: [], rejectedFieldIds: []
        )
        return DictationProposalReconciler.reconcile(
            request: request, labeled: labeled, explicit: explicit, generated: naturalLanguage
        )
    }

    private static func patientName(in request: DictationParseRequest) -> VoiceFieldProposal? {
        let text = request.text
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.setLanguage(
            NLLanguage(rawValue: request.locale.language.languageCode?.identifier ?? ""),
            range: text.startIndex ..< text.endIndex
        )
        var matches: [String] = []
        tagger.enumerateTags(
            in: text.startIndex ..< text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, range in
            guard tag == .personalName else { return true }
            let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.split(whereSeparator: \.isWhitespace).count >= 2 else { return true }
            let prefix = String(text[..<range.lowerBound].suffix(48))
            guard prefix.range(
                of: #"(?i)(?:\bpatient\b|\bfor\b|\bпациент\b|\bпри[её]ме\b)[^.!?;]*$"#,
                options: .regularExpression
            ) != nil else { return true }
            matches.append(name)
            return true
        }
        guard matches.count == 1, let name = matches.first,
              text.range(of: name) != nil
        else { return nil }
        let value = VoiceFieldValue.text(name)
        return VoiceFieldProposal(
            id: .patientName,
            value: value,
            sourceQuote: name,
            warnings: DictationProposalValidator.warnings(
                fieldId: .patientName, value: value, sourceQuote: name, request: request
            )
        )
    }
}
