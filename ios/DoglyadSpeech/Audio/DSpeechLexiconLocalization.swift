import Foundation

/// Language data for conservative spelling correction, supplied by the app.
public struct DSpeechLexiconLocalization: Decodable, Sendable {
    public let negationPattern: String
    public let leftSidePattern: String
    public let rightSidePattern: String
    public let literalCharacterReplacements: [String: String]
    public let phoneticCharacterReplacements: [String: String]
    public let ignoredPhoneticCharacters: String

    private enum DSpeechLexiconCodingKeys: String, CodingKey {
        case negationPattern, leftSidePattern, rightSidePattern
        case literalCharacterReplacements, phoneticCharacterReplacements, ignoredPhoneticCharacters
    }

    public init(
        from decoder: Decoder,
    ) throws {
        let container = try decoder.container(
            keyedBy: DSpeechLexiconCodingKeys.self,
        )
        negationPattern = try container.decode(
            String.self,
            forKey: .negationPattern,
        )
        leftSidePattern = try container.decode(
            String.self,
            forKey: .leftSidePattern,
        )
        rightSidePattern = try container.decode(
            String.self,
            forKey: .rightSidePattern,
        )
        literalCharacterReplacements = try container.decode(
            [String: String].self,
            forKey: .literalCharacterReplacements,
        )
        phoneticCharacterReplacements = try container.decode(
            [String: String].self,
            forKey: .phoneticCharacterReplacements,
        )
        ignoredPhoneticCharacters = try container.decode(
            String.self,
            forKey: .ignoredPhoneticCharacters,
        )

        for expression in [negationPattern, leftSidePattern, rightSidePattern] {
            _ = try NSRegularExpression(
                pattern: expression,
                options: .caseInsensitive,
            )
        }
        guard (literalCharacterReplacements.merging(
            phoneticCharacterReplacements,
        ) { first, _ in first })
            .allSatisfy(
                { $0.key.count == 1 && $0.value.count == 1 },
            )
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .phoneticCharacterReplacements,
                in: container,
                debugDescription: "Character mappings must contain single characters",
            )
        }
    }
}
