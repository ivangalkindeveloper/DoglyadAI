import Foundation

/// Normalizes recognized text to the canonical examination vocabulary.
///
/// The recognizer can confuse similar-sounding medical words. The parsing model can
/// no longer repair such misses because it does not know what was actually said. Before
/// parsing, the text is therefore compared with a dictionary of canonical terms.
///
/// Comparison uses a phonetic skeleton rather than raw spelling because recognition
/// errors usually follow sound instead of orthography.
///
/// Clinical facts are immutable: the algorithm never adds or removes a negation or
/// a side, and never touches phrases with numbers. Small edit distances can otherwise
/// connect statements with opposite meanings or different measurement values.
public struct DSpeechLexiconCorrector: Sendable {
    /// The allowed share of edits relative to the term length. Chosen conservatively:
    /// missing a fix is cheaper than replacing what the physician actually said.
    private static let maximumDistanceRatio = 0.16

    /// How far ahead of the runner-up the best candidate must be for a substitution
    /// to happen.
    ///
    /// The examination vocabulary contains many semantic opposites that differ by only
    /// a few letters. These pairs fall within the distance threshold, so refusing ties alone is
    /// not enough — a margin is needed. On a run over the whole dictionary with synthetic
    /// recognition errors, a margin of two edits removes substitution of one term by
    /// another entirely, at the cost of about one percent of the fixes.
    private static let minimumMargin = 2

    private struct DSpeechLexiconTerm: Sendable {
        let text: String
        let normalized: [Character]
        let wordEndings: [String]
        let hasNegation: Bool
        let sides: Set<DSpeechLexiconSide>
    }

    private enum DSpeechLexiconSide: Hashable, Sendable {
        case left
        case right
    }

    /// Terms are bucketed by word count: a window of text is compared only with
    /// terms of the same length.
    private let termsByWordCount: [Int: [DSpeechLexiconTerm]]
    private let maximumWordCount: Int
    private let localization: DSpeechLexiconLocalization

    public init(
        terms: [String],
        localization: DSpeechLexiconLocalization,
    ) {
        self.localization = localization
        var grouped: [Int: [DSpeechLexiconTerm]] = [:]

        for text in terms {
            let wordCount = text.split(
                separator: " ",
            ).count
            guard wordCount > 1 else { continue }

            let normalized = Self.normalize(
                text,
                localization: localization,
            )
            guard !normalized.isEmpty else { continue }

            grouped[
                wordCount,
                default: [],
            ].append(
                DSpeechLexiconTerm(
                    text: text,
                    normalized: normalized,
                    wordEndings: Self.wordEndings(
                        in: text,
                        localization: localization,
                    ),
                    hasNegation: Self.hasNegation(
                        text,
                        localization: localization,
                    ),
                    sides: Self.sides(
                        in: text,
                        localization: localization,
                    ),
                ),
            )
        }

        termsByWordCount = grouped
        maximumWordCount = grouped.keys.max() ?? 0
    }

    public func correct(
        _ text: String,
    ) -> String {
        guard maximumWordCount > 1 else { return text }

        let words = text.split(
            whereSeparator: \.isWhitespace,
        )
        guard !words.isEmpty else { return text }

        // The replacement starting at this index, and how many words it consumes.
        var replacements = [(text: String, length: Int)?](
            repeating: nil,
            count: words.count,
        )
        var isConsumed = [Bool](
            repeating: false,
            count: words.count,
        )

        // Process longer phrases first so they beat shorter terms nested inside them.
        for wordCount in stride(
            from: maximumWordCount,
            through: 2,
            by: -1,
        ) {
            guard let candidates = termsByWordCount[
                wordCount,
            ] else { continue }
            guard words.count >= wordCount else { continue }

            for start in 0 ... (words.count - wordCount) {
                let range = start ..< (start + wordCount)
                guard !isConsumed[
                    range,
                ].contains(
                    true,
                ) else { continue }

                // A dictionary phrase cannot span a sentence or a field label.
                guard !words[
                    range,
                ].dropLast().contains(
                    where: { word in
                        word.contains(
                            where: { ".;:!?".contains(
                                $0,
                            ) },
                        )
                    },
                ) else { continue }
                let window = String(
                    text[
                        words[
                            start,
                        ].startIndex ..< words[
                            range.upperBound - 1,
                        ].endIndex,
                    ],
                )
                guard let match = bestMatch(
                    for: window,
                    among: candidates,
                ) else { continue }

                replacements[
                    start,
                ] = (Self.render(
                    match,
                    preservingPunctuationOf: window,
                ), wordCount)
                for index in range {
                    isConsumed[
                        index,
                    ] = true
                }
            }
        }

        let result = NSMutableString(
            string: text,
        )
        for index in words.indices.reversed() {
            if let replacement = replacements[
                index,
            ] {
                let range = words[
                    index,
                ].startIndex ..< words[
                    index + replacement.length - 1,
                ].endIndex
                result.replaceCharacters(
                    in: NSRange(
                        range,
                        in: text,
                    ),
                    with: replacement.text,
                )
            }
        }
        return result as String
    }

    /// The nearest term, if it is close enough and noticeably closer than the rest.
    private func bestMatch(
        for window: String,
        among candidates: [DSpeechLexiconTerm],
    ) -> String? {
        guard !window.contains(
            where: \.isNumber,
        ) else { return nil }

        let normalized = Self.normalize(
            window,
            localization: localization,
        )
        guard !normalized.isEmpty else { return nil }

        let limit = Int(
            (Double(
                normalized.count,
            ) * Self.maximumDistanceRatio).rounded(),
        )
        guard limit > 0 else { return nil }

        let hasNegation = Self.hasNegation(
            window,
            localization: localization,
        )
        let sides = Self.sides(
            in: window,
            localization: localization,
        )
        let wordEndings = Self.wordEndings(
            in: window,
            localization: localization,
        )
        var best: DSpeechLexiconTerm?
        var bestDistance = Int.max
        var runnerUpDistance = Int.max

        for term in candidates {
            // Negation and side are immutable clinical facts.
            guard term.hasNegation == hasNegation, term.sides == sides else { continue }
            // Preserve inflection rather than forcing a canonical dictionary
            // ending: nodules != nodule; щитовидной железы != щитовидная железа.
            // This deliberately leaves misspelled endings for review.
            guard term.wordEndings == wordEndings else { continue }
            guard abs(
                term.normalized.count - normalized.count,
            ) <= limit else { continue }

            let distance = Self.distance(
                normalized,
                term.normalized,
                limit: limit,
            )
            guard distance <= limit else { continue }

            if distance < bestDistance {
                runnerUpDistance = bestDistance
                bestDistance = distance
                best = term
            } else if distance < runnerUpDistance {
                runnerUpDistance = distance
            }
        }

        guard let best else { return nil }
        // The nearest term must lead the next one noticeably — otherwise this is a
        // choice between semantic opposites, and we are not going to guess.
        guard runnerUpDistance - bestDistance >= Self.minimumMargin else { return nil }
        // A spelling already equivalent apart from ё and case needs no repair.
        guard Self.literalWords(
            in: best.text,
            localization: localization,
        ) != Self.literalWords(
            in: window,
            localization: localization,
        ) else { return nil }

        return best.text
    }

    private static func wordEndings(
        in text: String,
        localization: DSpeechLexiconLocalization,
    ) -> [String] {
        literalWords(
            in: text,
            localization: localization,
        ).map { String(
            $0.suffix(
                2,
            ),
        ) }
    }

    private static func literalWords(
        in text: String,
        localization: DSpeechLexiconLocalization,
    ) -> [String] {
        var normalized = text.lowercased()
        for (source, target) in localization.literalCharacterReplacements {
            normalized = normalized.replacingOccurrences(
                of: source,
                with: target,
            )
        }
        return normalized.split(
            whereSeparator: { !$0.isLetter },
        ).map(
            String.init,
        )
    }

    /// Collapse homophones by removing selected vowel distinctions, consonant voicing,
    /// soft and hard signs, repeated letters, and spaces.
    private static func normalize(
        _ text: String,
        localization: DSpeechLexiconLocalization,
    ) -> [Character] {
        var result: [Character] = []
        result.reserveCapacity(
            text.count,
        )

        for character in text.lowercased() {
            guard character.isLetter || character.isNumber else { continue }
            guard !localization.ignoredPhoneticCharacters.contains(
                character,
            ) else { continue }

            let mapped = localization.phoneticCharacterReplacements[
                String(
                    character,
                ),
            ]?.first ?? character
            guard result.last != mapped else { continue }

            result.append(
                mapped,
            )
        }

        return result
    }

    private static func hasNegation(
        _ text: String,
        localization: DSpeechLexiconLocalization,
    ) -> Bool {
        text.lowercased().split(
            whereSeparator: { !$0.isLetter },
        ).contains { token in
            token.range(
                of: localization.negationPattern,
                options: [.regularExpression, .caseInsensitive],
            ) != nil
        }
    }

    private static func sides(
        in text: String,
        localization: DSpeechLexiconLocalization,
    ) -> Set<DSpeechLexiconSide> {
        var found: Set<DSpeechLexiconSide> = []
        for token in text.lowercased().split(
            whereSeparator: { !$0.isLetter },
        ) {
            if token.range(
                of: localization.leftSidePattern,
                options: [.regularExpression, .caseInsensitive],
            ) != nil {
                found.insert(
                    .left,
                )
            }
            if token.range(
                of: localization.rightSidePattern,
                options: [.regularExpression, .caseInsensitive],
            ) != nil {
                found.insert(
                    .right,
                )
            }
        }
        return found
    }

    /// Levenshtein distance with an early exit: once the entire row has gone past the
    /// threshold, computing the rest is pointless.
    private static func distance(
        _ lhs: [Character],
        _ rhs: [Character],
        limit: Int,
    ) -> Int {
        guard !lhs.isEmpty else { return rhs.count }
        guard !rhs.isEmpty else { return lhs.count }

        var previous = Array(
            0 ... rhs.count,
        )
        var current = [Int](
            repeating: 0,
            count: rhs.count + 1,
        )

        for lhsIndex in 1 ... lhs.count {
            current[
                0,
            ] = lhsIndex
            var rowMinimum = current[
                0,
            ]

            for rhsIndex in 1 ... rhs.count {
                let cost = lhs[
                    lhsIndex - 1,
                ] == rhs[
                    rhsIndex - 1,
                ] ? 0 : 1
                current[
                    rhsIndex,
                ] = min(
                    previous[
                        rhsIndex,
                    ] + 1,
                    current[
                        rhsIndex - 1,
                    ] + 1,
                    previous[
                        rhsIndex - 1,
                    ] + cost,
                )
                rowMinimum = min(
                    rowMinimum,
                    current[
                        rhsIndex,
                    ],
                )
            }

            guard rowMinimum <= limit else { return limit + 1 }

            swap(
                &previous,
                &current,
            )
        }

        return previous[
            rhs.count,
        ]
    }

    /// Terms in the dictionary are written in lower case, while in the text the phrase
    /// may have started a sentence — preserve the case of the first letter.
    private static func matchingCase(
        of window: String,
        for replacement: String,
    ) -> String {
        guard let first = window.first, first.isUppercase else { return replacement }

        return replacement.prefix(
            1,
        ).uppercased() + replacement.dropFirst()
    }

    private static func render(
        _ replacement: String,
        preservingPunctuationOf window: String,
    ) -> String {
        let canonical = matchingCase(
            of: window,
            for: replacement,
        ).split(
            separator: " ",
        )
        let original = window.split(
            whereSeparator: \.isWhitespace,
        )
        guard canonical.count == original.count else { return replacement }
        let result = NSMutableString(
            string: window,
        )
        for index in original.indices.reversed() {
            let source = original[
                index,
            ]
            let leading = source.prefix { !$0.isLetter && !$0.isNumber }
            let trailing = source.reversed().prefix { !$0.isLetter && !$0.isNumber }.reversed()
            result.replaceCharacters(
                in: NSRange(
                    source.startIndex ..< source.endIndex,
                    in: window,
                ),
                with: String(
                    leading,
                ) + canonical[
                    index,
                ] + String(
                    trailing,
                ),
            )
        }
        return result as String
    }
}
