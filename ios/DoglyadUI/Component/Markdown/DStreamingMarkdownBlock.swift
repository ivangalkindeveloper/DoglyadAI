import Foundation

struct DStreamingMarkdownBlock: Identifiable {
    struct Content: Equatable {
        enum Kind: Equatable {
            case paragraph
            case heading(Int)
            case fallback
        }

        struct Inline: Equatable {
            struct Style: OptionSet {
                let rawValue: Int
                static let strong = Self(
                    rawValue: 1,
                )
                static let emphasis = Self(
                    rawValue: 2,
                )
                static let code = Self(
                    rawValue: 4,
                )
                static let strikethrough = Self(
                    rawValue: 8,
                )
            }

            let text: String
            let style: Style
            let link: URL?
        }

        let kind: Kind
        let markdown: String
        let inlines: [Inline]
        var indent: Int = 0
        var marker: String?
        var topMargin: Double = 0
        var bottomMargin: Double = 16

        var text: String {
            inlines.map(
                \.text,
            ).joined()
        }
    }

    struct Reveal: Equatable {
        let range: Range<Int>
        let date: Date
        static let duration: TimeInterval = 0.15

        func opacity(
            at date: Date,
        ) -> Double {
            min(
                1,
                max(
                    0,
                    date.timeIntervalSince(
                        self.date,
                    ) / Self.duration,
                ),
            )
        }
    }

    let id: UUID
    let content: Content
    let reveals: [Reveal]
}
