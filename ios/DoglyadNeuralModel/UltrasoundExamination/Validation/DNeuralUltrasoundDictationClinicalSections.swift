import Foundation

/// Completes a model's short complaint quote up to a separately identified
/// finding. Recovered boundaries remain questionable and use only source text.
enum DNeuralUltrasoundDictationClinicalSections {
    static func complete(
        _ items: [DNeuralUltrasoundProposalGenerationItem],
        request: DNeuralUltrasoundDictationParseRequest,
    ) -> [DNeuralUltrasoundProposalGenerationItem] {
        let localization = request.localization
        guard let complaint = items.first(
            where: { $0.fieldId == .patientComplaints },
        ),
            let description = items.first(
                where: { $0.fieldId == .examinationDescription },
            )
        else { return items }
        let complaintValue = complaint.value.replacingOccurrences(
            of: #"^\s*(?:"# + DNeuralUltrasoundDictationSectionCue.complaint(
                localization: localization,
            ) + #")\s*[:,—-]?\s+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive],
        ).trimmingCharacters(
            in: .whitespacesAndNewlines.union(
                .punctuationCharacters,
            ),
        )
        guard !complaintValue.isEmpty,
              let start = uniqueRange(
                  complaintValue,
                  in: request.text,
              ),
              complaint.sourceQuote.range(
                  of: complaintValue,
                  options: .caseInsensitive,
              ) != nil
        else { return items }
        let suffix = String(
            request.text[
                start.upperBound...,
            ],
        )
        let observation = suffix.range(
            of: DNeuralUltrasoundDictationObservationCue.pattern(
                localization: localization,
            ),
            options: [.regularExpression, .caseInsensitive],
        )
        .map { request.text.index(
            start.upperBound,
            offsetBy: suffix.distance(
                from: suffix.startIndex,
                to: $0.lowerBound,
            ),
        ) }
        let descriptionValue = DNeuralUltrasoundDictationObservationCue.removeFraming(
            from: description.value,
            localization: localization,
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        let descriptionStart = uniqueRange(
            firstSentence(
                descriptionValue,
            ),
            in: request.text,
        )?.lowerBound
        var boundary = [observation, descriptionStart].compactMap(
            \.self,
        ).filter { $0 > start.lowerBound }.min()
        var recoveredDescription = false
        if boundary == nil,
           let descriptionRange = uniqueRange(
               descriptionValue,
               in: request.text,
           ),
           descriptionRange.lowerBound <= start.lowerBound
        {
            // When the model copies complaints into the description, an
            // independently measured finding in a later sentence can delimit
            // them. This inferred boundary always requires confirmation.
            boundary = sentenceRanges(
                in: request.text,
            ).first { range in
                range.lowerBound > start.upperBound
                    && range.upperBound <= descriptionRange.upperBound
                    && request.text[
                        range,
                    ].range(
                        of: localization.pattern(
                            .clinicalMeasurement,
                        ),
                        options: [.regularExpression, .caseInsensitive],
                    ) != nil
            }?.lowerBound
            recoveredDescription = boundary != nil
        }
        guard let boundary else { return items }
        let stopPattern = DNeuralUltrasoundDictationFollowingFieldCue.recordPattern(
            localization: localization,
        ) + "|" + DNeuralUltrasoundDictationFollowingFieldCue.patientPattern(
            localization: localization,
        )
            + "|" + DNeuralUltrasoundDictationSectionCue.measurement(
                localization: localization,
            )
        let passage = String(
            request.text[
                start.lowerBound ..< boundary,
            ],
        )
        guard passage.range(
            of: stopPattern,
            options: [.regularExpression, .caseInsensitive],
        ) == nil else { return items }
        let complete = passage.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        return items.map { item in
            switch item.fieldId {
            case .patientComplaints:
                guard complete.trimmingCharacters(
                    in: .punctuationCharacters,
                ) != complaintValue else { return item }
                return DNeuralUltrasoundProposalGenerationItem(
                    fieldId: item.fieldId,
                    value: complete,
                    sourceQuote: complete,
                    accuracy: .questionable,
                )
            case .examinationDescription:
                guard recoveredDescription, let range = uniqueRange(
                    descriptionValue,
                    in: request.text,
                ) else { return item }
                let value = String(
                    request.text[
                        boundary ..< range.upperBound,
                    ],
                ).trimmingCharacters(
                    in: .whitespacesAndNewlines,
                )
                return DNeuralUltrasoundProposalGenerationItem(
                    fieldId: item.fieldId,
                    value: value,
                    sourceQuote: value,
                    accuracy: .questionable,
                )
            case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth, .patientHeightCM, .patientWeightKG:
                return item
            }
        }
    }

    private static func uniqueRange(
        _ value: String,
        in text: String,
    ) -> Range<String.Index>? {
        guard !value.isEmpty, let range = text.range(
            of: value,
            options: .caseInsensitive,
        ),
            text.range(
                of: value,
                options: .caseInsensitive,
                range: range.upperBound ..< text.endIndex,
            ) == nil
        else { return nil }
        return range
    }

    private static func firstSentence(
        _ text: String,
    ) -> String {
        sentenceRanges(
            in: text,
        ).first.map { String(
            text[
                $0,
            ],
        ).trimmingCharacters(
            in: .whitespacesAndNewlines,
        ) } ?? text
    }

    private static func sentenceRanges(
        in text: String,
    ) -> [Range<String.Index>] {
        guard let expression = try? NSRegularExpression(
            pattern: #"[.!?](?=\s|$)|[;\n]"#,
        ) else { return [] }
        var start = text.startIndex
        var ranges: [Range<String.Index>] = []
        for match in expression.matches(
            in: text,
            range: NSRange(
                text.startIndex...,
                in: text,
            ),
        ) {
            guard let end = Range(
                match.range,
                in: text,
            )?.upperBound else { continue }
            while start < end, text[
                start,
            ].isWhitespace {
                start = text.index(
                    after: start,
                )
            }
            ranges.append(
                start ..< end,
            )
            start = end
        }
        if start < text.endIndex { ranges.append(
            start ..< text.endIndex,
        ) }
        return ranges
    }
}
