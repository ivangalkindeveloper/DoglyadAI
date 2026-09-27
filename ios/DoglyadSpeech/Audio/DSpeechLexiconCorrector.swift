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
/// Two substitutions are forbidden outright because they invert the meaning of a
/// report: the algorithm never adds or removes a negation and never touches phrases
/// with numbers. Small edit distances can otherwise connect statements with opposite
/// meanings or different measurement values.
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

    private struct Term: Sendable {
        let text: String
        let normalized: [Character]
        let hasNegation: Bool
    }

    /// Terms are bucketed by word count: a window of text is compared only with
    /// terms of the same length.
    private let termsByWordCount: [Int: [Term]]
    private let maximumWordCount: Int

    public init(
        terms: [String]
    ) {
        var grouped: [Int: [Term]] = [:]

        for text in terms {
            let wordCount = text.split(separator: " ").count
            guard wordCount > 1 else { continue }

            let normalized = Self.normalize(text)
            guard !normalized.isEmpty else { continue }

            grouped[wordCount, default: []].append(
                Term(
                    text: text,
                    normalized: normalized,
                    hasNegation: Self.hasNegation(text)
                )
            )
        }

        termsByWordCount = grouped
        maximumWordCount = grouped.keys.max() ?? 0
    }

    public func correct(
        _ text: String
    ) -> String {
        guard maximumWordCount > 1 else { return text }

        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return text }

        // The replacement starting at this index, and how many words it consumes.
        var replacements = [(text: String, length: Int)?](repeating: nil, count: words.count)
        var isConsumed = [Bool](repeating: false, count: words.count)

        // Process longer phrases first so they beat shorter terms nested inside them.
        for wordCount in stride(from: maximumWordCount, through: 2, by: -1) {
            guard let candidates = termsByWordCount[wordCount] else { continue }
            guard words.count >= wordCount else { continue }

            for start in 0 ... (words.count - wordCount) {
                let range = start ..< (start + wordCount)
                guard !isConsumed[range].contains(true) else { continue }

                let window = words[range].joined(separator: " ")
                guard let match = bestMatch(for: window, among: candidates) else { continue }

                replacements[start] = (Self.matchingCase(of: window, for: match), wordCount)
                for index in range {
                    isConsumed[index] = true
                }
            }
        }

        var result: [String] = []
        result.reserveCapacity(words.count)
        var index = 0
        while index < words.count {
            if let replacement = replacements[index] {
                result.append(replacement.text)
                index += replacement.length
            } else {
                result.append(words[index])
                index += 1
            }
        }

        return result.joined(separator: " ")
    }

    /// The nearest term, if it is close enough and noticeably closer than the rest.
    private func bestMatch(
        for window: String,
        among candidates: [Term]
    ) -> String? {
        guard !window.contains(where: \.isNumber) else { return nil }

        let normalized = Self.normalize(window)
        guard !normalized.isEmpty else { return nil }

        let limit = Int((Double(normalized.count) * Self.maximumDistanceRatio).rounded())
        guard limit > 0 else { return nil }

        let hasNegation = Self.hasNegation(window)
        var best: Term?
        var bestDistance = Int.max
        var runnerUpDistance = Int.max

        for term in candidates {
            // Negation is immutable: the algorithm must neither add nor remove it.
            guard term.hasNegation == hasNegation else { continue }
            guard abs(term.normalized.count - normalized.count) <= limit else { continue }

            let distance = Self.distance(normalized, term.normalized, limit: limit)
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

        return best.text
    }

    /// Collapse homophones by removing selected vowel distinctions, consonant voicing,
    /// soft and hard signs, repeated letters, and spaces.
    private static let phoneticMap: [Character: Character] = [
        "ё": "е",
        "э": "е",
        "й": "и",
        "ы": "и",
        "б": "п",
        "в": "ф",
        "г": "к",
        "д": "т",
        "ж": "ш",
        "з": "с",
    ]

    private static func normalize(
        _ text: String
    ) -> [Character] {
        var result: [Character] = []
        result.reserveCapacity(text.count)

        for character in text.lowercased() {
            guard character.isLetter || character.isNumber else { continue }
            guard character != "ь", character != "ъ" else { continue }

            let mapped = phoneticMap[character] ?? character
            guard result.last != mapped else { continue }

            result.append(mapped)
        }

        return result
    }

    private static let negations: Set<String> = ["не", "нет", "без", "no", "not", "without"]

    private static func hasNegation(
        _ text: String
    ) -> Bool {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .contains { negations.contains(String($0)) }
    }

    /// Levenshtein distance with an early exit: once the entire row has gone past the
    /// threshold, computing the rest is pointless.
    private static func distance(
        _ lhs: [Character],
        _ rhs: [Character],
        limit: Int
    ) -> Int {
        guard !lhs.isEmpty else { return rhs.count }
        guard !rhs.isEmpty else { return lhs.count }

        var previous = Array(0 ... rhs.count)
        var current = [Int](repeating: 0, count: rhs.count + 1)

        for lhsIndex in 1 ... lhs.count {
            current[0] = lhsIndex
            var rowMinimum = current[0]

            for rhsIndex in 1 ... rhs.count {
                let cost = lhs[lhsIndex - 1] == rhs[rhsIndex - 1] ? 0 : 1
                current[rhsIndex] = min(
                    previous[rhsIndex] + 1,
                    current[rhsIndex - 1] + 1,
                    previous[rhsIndex - 1] + cost
                )
                rowMinimum = min(rowMinimum, current[rhsIndex])
            }

            guard rowMinimum <= limit else { return limit + 1 }

            swap(&previous, &current)
        }

        return previous[rhs.count]
    }

    /// Terms in the dictionary are written in lower case, while in the text the phrase
    /// may have started a sentence — preserve the case of the first letter.
    private static func matchingCase(
        of window: String,
        for replacement: String
    ) -> String {
        guard let first = window.first, first.isUppercase else { return replacement }

        return replacement.prefix(1).uppercased() + replacement.dropFirst()
    }
}
