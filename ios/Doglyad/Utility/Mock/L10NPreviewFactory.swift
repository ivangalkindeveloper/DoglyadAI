#if DEBUG
    import Foundation

    enum L10NPreviewFactory {
        static func make(
            code: String = "ru",
        ) -> L10N {
            try! L10N(
                localization: DevelopmentPreviewFactory.make(
                    code: code,
                ).localization,
            )
        }
    }
#endif
