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

    static func normalizedPatientName(
        _ name: String,
        locale: Locale,
    ) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: #"[\p{L}]+"#,
        ) else { return name }
        let result = NSMutableString(
            string: name,
        )
        for match in expression.matches(
            in: name,
            range: NSRange(
                name.startIndex...,
                in: name,
            ),
        ).reversed() {
            let word = (name as NSString).substring(
                with: match.range,
            )
            if word == word.lowercased(
                with: locale,
            ) || word == word.uppercased(
                with: locale,
            ) {
                result.replaceCharacters(
                    in: match.range,
                    with: word.capitalized(
                        with: locale,
                    ),
                )
            }
        }
        return result as String
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

        if let expression = try? NSRegularExpression(
            pattern: localization.pattern(
                .groupedNumericBirthDate,
            ),
            options: .caseInsensitive,
        ),
            let match = expression.firstMatch(
                in: text,
                range: NSRange(
                    text.startIndex...,
                    in: text,
                ),
            ),
            match.range == NSRange(
                text.startIndex...,
                in: text,
            )
        {
            let source = text as NSString
            let parts = ["year", "month", "day"].compactMap { name -> Int? in
                let range = match.range(
                    withName: name,
                )
                guard range.location != NSNotFound else { return nil }
                return Int(
                    source.substring(
                        with: range,
                    ).filter(
                        \.isNumber,
                    ),
                )
            }
            if parts.count == 3 {
                let literal = String(
                    format: "%04d-%02d-%02d",
                    parts[
                        0,
                    ],
                    parts[
                        1,
                    ],
                    parts[
                        2,
                    ],
                )
                if let date = iso.date(
                    from: literal,
                ), iso.string(
                    from: date,
                ) == literal { return date }
            }
            return nil
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
            ) else { continue }
            switch formatter.string(
                from: date,
            ).localizedCaseInsensitiveCompare(
                text,
            ) {
            case .orderedSame: return date
            case .orderedAscending, .orderedDescending: continue
            }
        }
        return nil
    }
}
