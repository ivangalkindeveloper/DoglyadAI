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

                init(
                    rawValue: Int,
                ) {
                    self.rawValue = rawValue
                }

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

            init(
                text: String,
                style: Style,
                link: URL?,
            ) {
                self.text = text
                self.style = style
                self.link = link
            }
        }

        let kind: Kind
        let markdown: String
        let inlines: [Inline]
        var indent: Int = 0
        var marker: String?
        var topMargin: Double = 0
        var bottomMargin: Double = 16

        init(
            kind: Kind,
            markdown: String,
            inlines: [Inline],
            indent: Int = 0,
            marker: String? = nil,
            topMargin: Double = 0,
            bottomMargin: Double = 16,
        ) {
            self.kind = kind
            self.markdown = markdown
            self.inlines = inlines
            self.indent = indent
            self.marker = marker
            self.topMargin = topMargin
            self.bottomMargin = bottomMargin
        }

        var text: String {
            inlines.map(
                \.text,
            ).joined()
        }
    }

    struct Reveal: Equatable {
        let range: Range<Int>
        let date: Date

        init(
            range: Range<Int>,
            date: Date,
        ) {
            self.range = range
            self.date = date
        }

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

    init(
        id: UUID,
        content: Content,
        reveals: [Reveal],
    ) {
        self.id = id
        self.content = content
        self.reveals = reveals
    }
}
