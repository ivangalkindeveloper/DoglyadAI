import Combine
import Foundation

/// An immutable catalog for the language selected by the backend configuration.
/// Validate required keys once, before publishing the dependency container.
final class L10N: ObservableObject, Sendable {
    let locale: Locale
    let voice: VoiceLocalization
    private let strings: [L10NKey: String]
    private static let placeholderExpression = try! NSRegularExpression(
        pattern: #"(?<!\{)\{([A-Za-z][A-Za-z0-9]*)\}(?!\})"#,
    )

    init(
        localization: Localization,
    ) throws {
        var strings: [L10NKey: String] = [:]
        for key in L10NKey.allCases {
            guard let value = localization.strings[
                key.rawValue,
            ], !value.trimmingCharacters(
                in: .whitespacesAndNewlines,
            ).isEmpty else {
                throw L10NError.missingKey(
                    key,
                )
            }
            strings[
                key,
            ] = value
        }
        self.strings = strings
        locale = Locale(
            identifier: localization.code,
        )
        voice = localization.voice
    }

    subscript(
        key: L10NKey,
    ) -> LocalizedStringResource {
        resource(
            key,
        )
    }

    func text(
        _ key: L10NKey,
        values: [String: String] = [:],
    ) -> String {
        let template = strings[
            key,
        ]!
        guard !values.isEmpty else { return template }
        // Replace in the original template only. Inserted patient/user data is
        // literal, never a printf format or another template to evaluate.
        let expression = Self.placeholderExpression
        let matches = expression.matches(
            in: template,
            range: NSRange(
                template.startIndex...,
                in: template,
            ),
        )
        var result = template
        for match in matches.reversed() {
            guard let nameRange = Range(
                match.range(
                    at: 1,
                ),
                in: template,
            ),
                let replacement = values[
                    String(
                        template[
                            nameRange,
                        ],
                    ),
                ],
                let range = Range(
                    match.range,
                    in: result,
                ) else { continue }
            result.replaceSubrange(
                range,
                with: replacement,
            )
        }
        return result
    }

    func resource(
        _ key: L10NKey,
        values: [String: String] = [:],
    ) -> LocalizedStringResource {
        // A dynamic interpolation transports the literal server string through
        // DoglyadUI's existing resource API without looking up that string as a key.
        let value = text(
            key,
            values: values,
        )
        return LocalizedStringResource(
            "\(value)",
            locale: locale,
        )
    }
}
