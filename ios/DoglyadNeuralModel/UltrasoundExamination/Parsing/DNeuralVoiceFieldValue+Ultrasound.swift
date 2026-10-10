import Foundation

extension DNeuralVoiceFieldValue {
    static func parse(
        fieldId: DNeuralUltrasoundVoiceFieldId,
        text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) throws -> Self {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        guard !trimmed.isEmpty else { throw DNeuralUltrasoundDictationProposalError.invalidValue(
            fieldId,
        ) }

        switch fieldId {
        case .examinationNumber, .patientName, .patientComplaints, .examinationDescription:
            return .text(
                text,
            )
        case .patientGender:
            guard let gender = DNeuralVoiceGender(
                rawValue: trimmed,
            ) else {
                throw DNeuralUltrasoundDictationProposalError.invalidValue(
                    fieldId,
                )
            }
            return .gender(
                gender,
            )
        case .patientDateOfBirth:
            guard let date = parseCompleteDate(
                trimmed,
                locale: locale,
                localization: localization,
            ) else {
                throw DNeuralUltrasoundDictationProposalError.invalidValue(
                    fieldId,
                )
            }
            return .date(
                date,
            )
        case .patientHeightCM, .patientWeightKG:
            guard let number = Double(
                trimmed,
            ), number.isFinite, number > 0 else {
                throw DNeuralUltrasoundDictationProposalError.invalidValue(
                    fieldId,
                )
            }
            return .number(
                number,
            )
        }
    }

    private static func parseCompleteDate(
        _ text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(
            from: text,
        ), iso.string(
            from: date,
        ) == text {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(
            identifier: .gregorian,
        )
        formatter.timeZone = TimeZone(
            secondsFromGMT: 0,
        )
        formatter.isLenient = false
        for format in localization.dateFormats {
            formatter.dateFormat = format
            guard let date = formatter.date(
                from: text,
            ),
                formatter.string(
                    from: date,
                ).localizedCaseInsensitiveCompare(
                    text,
                ) == .orderedSame
            else { continue }
            return date
        }
        return nil
    }
}
