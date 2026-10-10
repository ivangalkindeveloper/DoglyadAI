import Foundation

/// Surface facts that can be compared without asking the generative model to
/// validate its own answer. Word order is retained for literal-substring checks.
struct DNeuralUltrasoundDictationTextFacts {
    let tokens: [String]
    let sides: Set<DNeuralSide>
    let negationCount: Int
    let numbers: Set<Double>
    let units: Set<DNeuralDictationUnit>
    let measurements: [DNeuralDictationUnit: Set<Double>]
    let hasUncertaintyCue: Bool

    init(
        _ text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) {
        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale,
        )
        let tokenList = Self.matches(
            #"[\p{L}\p{N}]+"#,
            in: normalized,
        )
        tokens = tokenList

        var sides = Set<DNeuralSide>()
        for token in tokens {
            if localization.matches(
                .leftSide,
                token,
            ) { sides.insert(
                .left,
            ) }
            if localization.matches(
                .rightSide,
                token,
            ) { sides.insert(
                .right,
            ) }
            if localization.matches(
                .bilateralSide,
                token,
            ) { sides.formUnion(
                [.left, .right],
            ) }
        }
        self.sides = sides
        negationCount = tokens.count(
            where: { localization.matches(
                .negation,
                $0,
            ) },
        )

        numbers = Set(
            Self.matches(
                #"(?<!\d)\d+(?:[.,]\d+)?(?!\d)"#,
                in: normalized,
            )
            .compactMap(
                Self.number,
            ),
        )

        var units = Set<DNeuralDictationUnit>()
        for word in Self.matches(
            #"[\p{L}%]+"#,
            in: normalized,
        ) {
            if let unit = DNeuralDictationUnit.fromWord(
                word,
                localization: localization,
            ) { units.insert(
                unit,
            ) }
        }
        self.units = units

        var measurements: [DNeuralDictationUnit: Set<Double>] = [:]
        if let regex = try? NSRegularExpression(
            pattern: #"(?<!\d)(\d+(?:[.,]\d+)?)\s*([\p{L}%]+)"#,
        ) {
            for match in regex.matches(
                in: normalized,
                range: NSRange(
                    normalized.startIndex...,
                    in: normalized,
                ),
            ) {
                guard let numberRange = Range(
                    match.range(
                        at: 1,
                    ),
                    in: normalized,
                ),
                    let unitRange = Range(
                        match.range(
                            at: 2,
                        ),
                        in: normalized,
                    ),
                    let number = Self.number(
                        String(
                            normalized[
                                numberRange,
                            ],
                        ),
                    ),
                    let unit = DNeuralDictationUnit.fromWord(
                        String(
                            normalized[
                                unitRange,
                            ],
                        ),
                        localization: localization,
                    )
                else { continue }
                measurements[
                    unit,
                    default: [],
                ].insert(
                    number,
                )
            }
        }
        self.measurements = measurements

        hasUncertaintyCue = localization.matches(
            .uncertainty,
            tokenList.joined(
                separator: " ",
            ),
        )
    }

    func containsLiteral(
        _ value: DNeuralUltrasoundDictationTextFacts,
    ) -> Bool {
        guard !value.tokens.isEmpty, value.tokens.count <= tokens.count else { return false }
        for start in 0 ... (tokens.count - value.tokens.count) {
            if Array(
                tokens[
                    start ..< start + value.tokens.count,
                ],
            ) == value.tokens { return true }
        }
        return false
    }

    private static func number(
        _ value: String,
    ) -> Double? {
        Double(
            value.replacingOccurrences(
                of: ",",
                with: ".",
            ),
        )
    }

    static func matches(
        _ pattern: String,
        in text: String,
    ) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
        ) else { return [] }
        return regex.matches(
            in: text,
            range: NSRange(
                text.startIndex...,
                in: text,
            ),
        ).compactMap { match in
            Range(
                match.range,
                in: text,
            ).map { String(
                text[
                    $0,
                ],
            ) }
        }
    }
}
