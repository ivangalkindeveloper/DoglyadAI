import Foundation

/// The application injects one catalog for the selected dictation language.
/// This module neither loads resources nor combines different languages.
public struct DNeuralUltrasoundDictationLocalization: Decodable, Sendable {
    private let patterns: [String: String]
    public let namePatterns: [String]
    public let genderPatterns: [String]
    public let numbers: DNeuralDictationNumberLocalization
    public let negativeCorrectionWord: String
    public let usesDayFirstNumericDates: Bool
    public let birthEvidenceUsesValue: Bool
    public let dateFormats: [String]
    public let shortUnits: DNeuralDictationShortUnitLocalization
    public let schema: DNeuralUltrasoundSchemaLocalization

    private enum DNeuralUltrasoundCodingKeys: String, CodingKey {
        case patterns, namePatterns, genderPatterns, numbers, negativeCorrectionWord
        case usesDayFirstNumericDates, birthEvidenceUsesValue, dateFormats, shortUnits, schema
    }

    public init(
        from decoder: Decoder,
    ) throws {
        let container = try decoder.container(
            keyedBy: DNeuralUltrasoundCodingKeys.self,
        )
        patterns = try container.decode(
            [String: String].self,
            forKey: .patterns,
        )
        namePatterns = try container.decode(
            [String].self,
            forKey: .namePatterns,
        )
        genderPatterns = try container.decode(
            [String].self,
            forKey: .genderPatterns,
        )
        numbers = try container.decode(
            DNeuralDictationNumberLocalization.self,
            forKey: .numbers,
        )
        negativeCorrectionWord = try container.decode(
            String.self,
            forKey: .negativeCorrectionWord,
        )
        usesDayFirstNumericDates = try container.decode(
            Bool.self,
            forKey: .usesDayFirstNumericDates,
        )
        birthEvidenceUsesValue = try container.decode(
            Bool.self,
            forKey: .birthEvidenceUsesValue,
        )
        dateFormats = try container.decode(
            [String].self,
            forKey: .dateFormats,
        )
        shortUnits = try container.decode(
            DNeuralDictationShortUnitLocalization.self,
            forKey: .shortUnits,
        )
        schema = try container.decode(
            DNeuralUltrasoundSchemaLocalization.self,
            forKey: .schema,
        )

        guard Set(
            patterns.keys,
        ) == Set(
            DNeuralUltrasoundDictationLocalizationKey.allCases.map(
                \.rawValue,
            ),
        ),
            !negativeCorrectionWord.isEmpty, !dateFormats.isEmpty,
            numbers.ones.count == 20, numbers.tens.count == 10, !numbers.hundred.isEmpty,
            !numbers.digits.isEmpty,
            numbers.digits.values.allSatisfy(
                { $0.count == 1 && $0.first?.isASCII == true && $0.first?.isNumber == true },
            )
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .patterns,
                in: container,
                debugDescription: "Incomplete dictation localization catalog",
            )
        }
        for expression in Array(
            patterns.values,
        ) + namePatterns + genderPatterns {
            guard !expression.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .patterns,
                    in: container,
                    debugDescription: "Empty dictation localization pattern",
                )
            }
            _ = try NSRegularExpression(
                pattern: expression,
                options: .caseInsensitive,
            )
        }
    }

    public func pattern(
        _ key: DNeuralUltrasoundDictationLocalizationKey,
    ) -> String {
        // Completeness is checked once during decoding.
        patterns[
            key.rawValue,
        ]!
    }

    func matches(
        _ key: DNeuralUltrasoundDictationLocalizationKey,
        _ text: String,
    ) -> Bool {
        text.range(
            of: pattern(
                key,
            ),
            options: [.regularExpression, .caseInsensitive],
        ) != nil
    }
}
