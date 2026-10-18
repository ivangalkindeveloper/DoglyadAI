#if DEBUG
    import Foundation

    enum L10NPreviewFactory {
        static func make(
            code: String = "ru",
        ) -> L10N {
            let fallback = L10N.previewable(
                code: code,
            )
            let catalogURL = URL(
                filePath: #filePath,
            )
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(
                path: "backend/main/config/development/\(code)/l10n_application.json",
            )
            // Canvas reads the backend source directly without bundling translations.
            do {
                let strings = try JSONDecoder().decode(
                    [String: String].self,
                    from: Data(
                        contentsOf: catalogURL,
                    ),
                )
                return try L10N(
                    localization: Localization(
                        code: code,
                        strings: strings,
                        voice: fallback.voice,
                    ),
                )
            } catch {
                return fallback
            }
        }
    }
#endif
