import SwiftUI

enum DStreamingMarkdownTextRenderer {
    static func text(
        for block: DStreamingMarkdownBlock,
        date: Date,
        color: DColor,
        textColor: Color?,
    ) -> AttributedString {
        let primary = textColor ?? color.grayscaleHeader
        var result = AttributedString()
        for inline in block.content.inlines {
            var text = AttributedString(
                inline.text,
            )
            text.font = font(
                kind: block.content.kind,
                style: inline.style,
                isLink: inline.link != nil,
            )
            text.foregroundColor = primary
            if block.content.kind == .heading(
                6,
            ) {
                text.foregroundColor = textColor == nil ? color.grayscaleLabel : primary.opacity(
                    0.82,
                )
            }
            if inline.style.contains(
                .strikethrough,
            ) {
                text.inlinePresentationIntent = .strikethrough
                text.foregroundColor = color.grayscalePlacehold
            }
            if inline.style.contains(
                .code,
            ) {
                text.backgroundColor = color.primaryDefaultStrong.opacity(
                    0.14,
                )
            }
            if let link = inline.link {
                text.link = link
                text.foregroundColor = color.primaryDefaultWeak
            }
            result.append(
                text,
            )
        }
        for reveal in block.reveals {
            let opacity = reveal.opacity(
                at: date,
            )
            guard opacity < 1,
                  let lower = result.characters.index(
                      result.startIndex,
                      offsetBy: reveal.range.lowerBound,
                      limitedBy: result.endIndex,
                  ),
                  let upper = result.characters.index(
                      lower,
                      offsetBy: reveal.range.count,
                      limitedBy: result.endIndex,
                  )
            else {
                continue
            }
            // Only color changes during reveal; all glyphs already participate in layout.
            let runs = Array(
                result[
                    lower ..< upper,
                ].runs,
            )
            for run in runs {
                result[
                    run.range,
                ].foregroundColor = (run.foregroundColor ?? primary).opacity(
                    opacity,
                )
                if let background = run.backgroundColor {
                    result[
                        run.range,
                    ].backgroundColor = background.opacity(
                        opacity,
                    )
                }
            }
        }
        return result
    }

    private static func font(
        kind: DStreamingMarkdownBlock.Content.Kind,
        style: DStreamingMarkdownBlock.Content.Inline.Style,
        isLink: Bool,
    ) -> Font {
        var family = DFontFamily.MontserratRegular
        var size: Double = 16
        switch kind {
        case let .heading(
            level,
        ):
            size = [1: 24, 2: 20, 3: 17, 4: 14, 5: 13, 6: 13][
                level,
            ] ?? 16
            family = level <= 2 ? .MontserratBold : (level == 6 ? .MontserratMedium : .MontserratSemiBold)
        case .paragraph, .fallback: break
        }
        if style.contains(
            .strong,
        ) {
            family = .MontserratSemiBold
            size = 14
        }
        if style.contains(
            .emphasis,
        ) {
            size = 14
        }
        if isLink {
            family = .MontserratSemiBold
            size = 16
        }
        var font = Font.custom(
            family,
            size,
        )
        if style.contains(
            .code,
        ) {
            font = .system(
                size: size * 0.92,
                design: .monospaced,
            )
        }
        if style.contains(
            .emphasis,
        ) {
            font = font.italic()
        }
        return font
    }
}
