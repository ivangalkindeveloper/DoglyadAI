import Foundation

/// Decoder diagnostics for a literal part of the final transcript. These are
/// model scores and repeat stability, not calibrated acoustic probabilities.
public struct DSpeechDecodingSpan: Sendable {
    public let utf16Start: Int
    public let utf16Length: Int
    public let averageLogProbability: Double
    public let temperature: Double
    public let compressionRatio: Double
    public let recheckedText: String?

    public init(
        utf16Start: Int,
        utf16Length: Int,
        averageLogProbability: Double,
        temperature: Double,
        compressionRatio: Double,
        recheckedText: String?,
    ) {
        self.utf16Start = utf16Start
        self.utf16Length = utf16Length
        self.averageLogProbability = averageLogProbability
        self.temperature = temperature
        self.compressionRatio = compressionRatio
        self.recheckedText = recheckedText
    }

    public func isStable(
        quote: String,
    ) -> Bool {
        guard let recheckedText else { return false }
        let literal = Self.normalized(
            quote,
        )
        return !literal.isEmpty && (" " + Self.normalized(
            recheckedText,
        ) + " ").contains(
            " " + literal + " ",
        )
    }

    private static func normalized(
        _ text: String,
    ) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: #"\d+(?:[.,]\d+)?|[^\W\d_]+"#,
        ) else { return "" }
        let value = text.lowercased()
        return expression.matches(
            in: value,
            range: NSRange(
                value.startIndex...,
                in: value,
            ),
        )
        .compactMap { Range(
            $0.range,
            in: value,
        ).map { String(
            value[
                $0,
            ],
        ) } }.joined(
            separator: " ",
        )
    }
}
