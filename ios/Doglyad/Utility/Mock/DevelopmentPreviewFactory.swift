#if DEBUG
    import Foundation

    enum DevelopmentPreviewFactory {
        static let russian = load(
            code: "ru",
        )
        static let english = load(
            code: "en",
        )

        static func make(
            code: String = "ru",
        ) -> DevelopmentPreviewData {
            code == "en" ? english : russian
        }

        private static func load(
            code: String,
        ) -> DevelopmentPreviewData {
            let url = URL(
                filePath: #filePath,
            )
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(
                path: "test/fixtures/development/\(code).json",
            )
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                return try decoder.decode(
                    DevelopmentPreviewData.self,
                    from: Data(
                        contentsOf: url,
                    ),
                )
            } catch {
                preconditionFailure(
                    "Update Development previews with python3 test/scripts/preview_fixtures.py: \(error)",
                )
            }
        }
    }
#endif
