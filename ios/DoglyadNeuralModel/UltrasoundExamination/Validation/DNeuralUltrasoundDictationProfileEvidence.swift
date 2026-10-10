import Foundation

/// Recognizes a quote made entirely of explicit profile fields. Any unknown
/// sentence leaves the quote available for clinical validation and review.
enum DNeuralUltrasoundDictationProfileEvidence {
    private static func labels(
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> [(DNeuralUltrasoundVoiceFieldId, String)] {
        [
            (.patientName, localization.pattern(
                .profilePatientName,
            )),
            (.patientDateOfBirth, localization.pattern(
                .profilePatientDateOfBirth,
            )),
            (.patientHeightCM, localization.pattern(
                .profilePatientHeightCM,
            )),
            (.patientWeightKG, localization.pattern(
                .profilePatientWeightKG,
            )),
            (.patientGender, localization.pattern(
                .profilePatientGender,
            )),
            (.examinationNumber, localization.pattern(
                .profileExaminationNumber,
            )),
            (.patientComplaints, localization.pattern(
                .profilePatientComplaints,
            )),
        ]
    }

    static func containsOnlyProfile(
        _ quote: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        let labelPattern = labels(
            localization: localization,
        ).map { "(?:" + $0.1 + ")" }.joined(
            separator: "|",
        )
        let sentences = quote.replacingOccurrences(
            of: #"[.!?;](?=\s|$)"#,
            with: "\n",
            options: .regularExpression,
        ).split(
            separator: "\n",
        ).map { $0.trimmingCharacters(
            in: .whitespacesAndNewlines,
        ) }.filter { !$0.isEmpty }
        var pendingLabel: String?
        for sentence in sentences {
            if matches(
                labelPattern,
                sentence,
            ) {
                guard pendingLabel == nil else { return false }
                pendingLabel = sentence
            } else {
                let joined = pendingLabel.map { $0 + ": " + sentence } ?? sentence
                guard isProfileSentence(
                    joined,
                    locale: locale,
                    localization: localization,
                ) else { return false }
                pendingLabel = nil
            }
        }
        return !sentences.isEmpty && pendingLabel == nil
    }

    private static func isProfileSentence(
        _ sentence: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        for (fieldId, label) in labels(
            localization: localization,
        ) {
            guard let prefix = sentence.range(
                of: #"^(?:"# + label + #")(?:\s*[:.,—–-]\s*|\s+)"#,
                options: [.regularExpression, .caseInsensitive],
            ) else { continue }
            let value = String(
                sentence[
                    prefix.upperBound...,
                ],
            ).trimmingCharacters(
                in: .whitespacesAndNewlines,
            )
            switch fieldId {
            case .patientName:
                return value.range(
                    of: #"^\p{Lu}[\p{L}'’\-]*(?:\s+\p{Lu}[\p{L}'’\-]*){0,2}$"#,
                    options: .regularExpression,
                ) != nil
            case .patientDateOfBirth:
                return (try? DNeuralVoiceFieldValue.parse(
                    fieldId: fieldId,
                    text: value,
                    locale: locale,
                    localization: localization,
                )) != nil
            case .patientHeightCM:
                return matches(
                    localization.pattern(
                        .profileHeight,
                    ),
                    value,
                )
            case .patientWeightKG:
                return matches(
                    localization.pattern(
                        .profileWeight,
                    ),
                    value,
                )
            case .patientGender:
                return matches(
                    localization.pattern(
                        .profileGender,
                    ),
                    value,
                )
            case .examinationNumber:
                return matches(
                    #"[\p{L}\p{N}]+(?:[-_/][\p{L}\p{N}]+)*"#,
                    value,
                )
            case .patientComplaints:
                return matches(
                    localization.pattern(
                        .profileNoComplaints,
                    ),
                    value,
                )
            case .examinationDescription:
                return false
            }
        }
        return false
    }

    private static func matches(
        _ pattern: String,
        _ value: String,
    ) -> Bool {
        value.range(
            of: "^(?:" + pattern + ")$",
            options: [.regularExpression, .caseInsensitive],
        ) != nil
    }
}
