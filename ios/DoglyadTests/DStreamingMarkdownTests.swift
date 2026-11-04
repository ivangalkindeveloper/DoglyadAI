@testable import DoglyadUI
import Foundation
import SwiftUI
import Testing
import UIKit

@MainActor
struct DStreamingMarkdownTests {
    private let streamID = UUID()
    private let date = Date(
        timeIntervalSince1970: 1000,
    )

    @Test
    func parsesHeadingsInlineStylesAndNestedLists() throws {
        let blocks = DStreamingMarkdownParser.parse(
            """
            ### Описание
            Контуры **ровные**, *чёткие*. `45 мм`. ~~нет~~ [Источник](https://example.com).

            3. Правая доля
               - Размеры сохранены
            4. Левая доля
            """,
        )
        #expect(
            blocks.count == 5,
        )
        #expect(
            blocks[
                0,
            ].kind == .heading(
                3,
            ),
        )
        #expect(
            blocks[
                0,
            ].bottomMargin == 8,
        )
        #expect(
            blocks[
                1,
            ].text == "Контуры ровные, чёткие. 45 мм. нет Источник.",
        )
        #expect(
            blocks[
                1,
            ].inlines.contains {
                $0.text == "ровные" && $0.style.contains(
                    .strong,
                )
            },
        )
        #expect(
            blocks[
                1,
            ].inlines.contains {
                $0.text == "чёткие" && $0.style.contains(
                    .emphasis,
                )
            },
        )
        #expect(
            blocks[
                1,
            ].inlines.contains {
                $0.text == "45 мм" && $0.style.contains(
                    .code,
                )
            },
        )
        #expect(
            blocks[
                1,
            ].inlines.contains {
                $0.text == "нет" && $0.style.contains(
                    .strikethrough,
                )
            },
        )
        #expect(
            blocks[
                1,
            ].inlines.contains {
                $0.link?.absoluteString == "https://example.com"
            },
        )
        #expect(
            blocks[
                2,
            ].marker == "3.",
        )
        #expect(
            blocks[
                3,
            ].marker == "•",
        )
        #expect(
            blocks[
                3,
            ].indent == 2,
        )
        #expect(
            blocks[
                4,
            ].marker == "4.",
        )
    }

    @Test
    func preservesComplexMarkdownAsFallbackBlocks() {
        let blocks = DStreamingMarkdownParser.parse(
            """
            | Доля | Размер |
            | --- | --- |
            | Правая | 45 мм |

            ```json
            {"value": 45}
            ```

            > Цитата

            ![Снимок](https://example.com/image.png)

            - [x] Проверено
            """,
        )
        #expect(
            blocks.count == 5,
        )
        #expect(
            blocks.allSatisfy {
                $0.kind == .fallback && !$0.markdown.isEmpty
            },
        )
        #expect(
            blocks[
                0,
            ].markdown.contains(
                "Правая",
            ),
        )
        #expect(
            blocks[
                1,
            ].markdown.contains(
                "\"value\": 45",
            ),
        )
        #expect(
            blocks[
                3,
            ].markdown.contains(
                "https://example.com/image.png",
            ),
        )
    }

    @Test
    func resolvesReferenceLinksAndEscapesWithoutLosingText() {
        let blocks = DStreamingMarkdownParser.parse(
            "[Описание][ref] &amp; \\*текст\\*\n\n[ref]: https://example.com",
        )
        #expect(
            blocks.count == 1,
        )
        #expect(
            blocks[
                0,
            ].text == "Описание & *текст*",
        )
        #expect(
            blocks[
                0,
            ].inlines.first?.link?.absoluteString == "https://example.com",
        )
    }

    @Test
    func appendedTextKeepsBlockIdentityAndRevealsOnlyTheSuffix() throws {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "### Описание\nКонтуры ровные",
            isStreaming: true,
            date: date,
        )
        let initial = controller.blocks
        controller.update(
            streamID: streamID,
            content: "### Описание\nКонтуры ровные, чёткие.",
            isStreaming: true,
            date: date.addingTimeInterval(
                1,
            ),
        )
        #expect(
            controller.blocks.map(
                \.id,
            ) == initial.map(
                \.id,
            ),
        )
        #expect(
            controller.blocks[
                0,
            ].reveals.isEmpty,
        )
        let reveal = try #require(
            controller.blocks[
                1,
            ].reveals.first,
        )
        #expect(
            reveal.range == "Контуры ровные".count ..< "Контуры ровные, чёткие.".count,
        )
        #expect(
            controller.blocks[
                1,
            ].reveals.count == 1,
        )
        #expect(
            reveal.opacity(
                at: date.addingTimeInterval(
                    1,
                ),
            ) == 0,
        )
        #expect(
            abs(
                reveal.opacity(
                    at: date.addingTimeInterval(
                        1.075,
                    ),
                ) - 0.5,
            ) < 0.001,
        )
    }

    @Test
    func rapidUpdatesDoNotRestartThePreviousReveal() {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "Контуры",
            isStreaming: true,
            date: date,
        )
        controller.update(
            streamID: streamID,
            content: "Контуры ровные",
            isStreaming: true,
            date: date.addingTimeInterval(
                0.05,
            ),
        )
        #expect(
            controller.blocks[
                0,
            ].reveals.map(
                \.date,
            ) == [date, date.addingTimeInterval(
                0.05,
            )],
        )
        #expect(
            controller.blocks[
                0,
            ].reveals.map(
                \.range,
            ) == [0 ..< 7, 7 ..< 14],
        )
    }

    @Test
    func closingEmphasisKeepsIdentityAndDoesNotFadeExistingWordsAgain() {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "Контуры **ровные",
            isStreaming: true,
            date: date,
        )
        let id = controller.blocks[
            0,
        ].id
        controller.update(
            streamID: streamID,
            content: "Контуры **ровные**",
            isStreaming: true,
            date: date.addingTimeInterval(
                0.05,
            ),
        )
        #expect(
            controller.blocks[
                0,
            ].id == id,
        )
        #expect(
            controller.blocks[
                0,
            ].content.text == "Контуры ровные",
        )
        #expect(
            controller.blocks[
                0,
            ].reveals.isEmpty,
        )
        #expect(
            controller.blocks[
                0,
            ].content.inlines.last?.style.contains(
                .strong,
            ) == true,
        )
    }

    @Test
    func correctionsKeepUnchangedBlocksAndReplaceOnlyTheAffectedText() {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "Размер 45 мм.\n\nЗаключение.",
            isStreaming: true,
            date: date,
        )
        let ids = controller.blocks.map(
            \.id,
        )
        controller.update(
            streamID: streamID,
            content: "Размер 43 мм.\n\nЗаключение.",
            isStreaming: true,
            date: date.addingTimeInterval(
                1,
            ),
        )
        #expect(
            controller.blocks.map(
                \.id,
            ) == ids,
        )
        #expect(
            controller.blocks[
                0,
            ].content.text == "Размер 43 мм.",
        )
        let isFullyVisible = controller.blocks.allSatisfy(
            \.reveals.isEmpty,
        )
        #expect(
            isFullyVisible,
        )
    }

    @Test
    func insertionAndDuplicateParagraphsKeepDistinctStableIdentities() {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "Повтор.\n\nПовтор.",
            isStreaming: true,
            date: date,
        )
        let ids = controller.blocks.map(
            \.id,
        )
        #expect(
            Set(
                ids,
            ).count == 2,
        )
        controller.update(
            streamID: streamID,
            content: "### Описание\nПовтор.\n\nПовтор.",
            isStreaming: true,
            date: date.addingTimeInterval(
                1,
            ),
        )
        #expect(
            Array(
                controller.blocks.dropFirst().map(
                    \.id,
                ),
            ) == ids,
        )
    }

    @Test
    func completionOrFailureImmediatelyRevealsAllReceivedText() {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "Текст",
            isStreaming: true,
            date: date,
        )
        let id = controller.blocks[
            0,
        ].id
        controller.update(
            streamID: streamID,
            content: "Текст полностью.",
            isStreaming: false,
            date: date.addingTimeInterval(
                0.02,
            ),
        )
        #expect(
            controller.blocks[
                0,
            ].id == id,
        )
        #expect(
            controller.blocks[
                0,
            ].content.text == "Текст полностью.",
        )
        #expect(
            controller.blocks[
                0,
            ].reveals.isEmpty,
        )
        #expect(
            controller.animationEnd == nil,
        )
    }

    @Test
    func retryResetsIdentityEvenWhenTheNewTextIsIdentical() {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "Текст",
            isStreaming: false,
            date: date,
        )
        let id = controller.blocks[
            0,
        ].id
        controller.update(
            streamID: UUID(),
            content: "Текст",
            isStreaming: true,
            date: date.addingTimeInterval(
                1,
            ),
        )
        #expect(
            controller.blocks[
                0,
            ].id != id,
        )
        #expect(
            controller.blocks[
                0,
            ].reveals.first?.range == 0 ..< 5,
        )
    }

    @Test
    func emptySnapshotsAndEmojiUpdatesDoNotCreateInvalidRanges() {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "",
            isStreaming: true,
            date: date,
        )
        #expect(
            controller.blocks.isEmpty,
        )
        controller.update(
            streamID: streamID,
            content: "👩‍⚕️ Размер",
            isStreaming: true,
            date: date,
        )
        controller.update(
            streamID: streamID,
            content: "👩‍⚕️ Размер 45 мм",
            isStreaming: true,
            date: date.addingTimeInterval(
                1,
            ),
        )
        #expect(
            controller.blocks[
                0,
            ].reveals.first?.range == "👩‍⚕️ Размер".count ..< "👩‍⚕️ Размер 45 мм".count,
        )
        controller.update(
            streamID: streamID,
            content: "",
            isStreaming: false,
            date: date,
        )
        #expect(
            controller.blocks.isEmpty,
        )
        #expect(
            controller.animationEnd == nil,
        )
    }

    @Test
    func revealChangesOnlyNewTextColorAndPreservesLinks() throws {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "Контуры",
            isStreaming: false,
            date: date,
        )
        controller.update(
            streamID: streamID,
            content: "Контуры [ровные](https://example.com)",
            isStreaming: true,
            date: date,
        )
        let block = try #require(
            controller.blocks.first,
        )
        let hidden = DStreamingMarkdownTextRenderer.text(
            for: block,
            date: date,
            color: .light,
            textColor: .black,
        )
        let visible = DStreamingMarkdownTextRenderer.text(
            for: block,
            date: date.addingTimeInterval(
                1,
            ),
            color: .light,
            textColor: .black,
        )
        #expect(
            String(
                hidden.characters,
            ) == "Контуры ровные",
        )
        #expect(
            hidden.characters.elementsEqual(
                visible.characters,
            ),
        )
        #expect(
            hidden.runs.first?.foregroundColor == Color.black,
        )
        #expect(
            hidden.runs.last?.foregroundColor == DColor.light.primaryDefaultWeak.opacity(
                0,
            ),
        )
        #expect(
            visible.runs.last?.foregroundColor == DColor.light.primaryDefaultWeak,
        )
        #expect(
            hidden.runs.last?.link?.absoluteString == "https://example.com",
        )
        let hiddenFonts = hidden.runs.flatMap { run in
            Array(
                repeating: run.font,
                count: hidden[
                    run.range,
                ].characters.count,
            )
        }
        let visibleFonts = visible.runs.flatMap { run in
            Array(
                repeating: run.font,
                count: visible[
                    run.range,
                ].characters.count,
            )
        }
        #expect(
            hiddenFonts == visibleFonts,
        )
    }

    @Test
    func multilineTextHasItsFullHeightBeforeRevealStarts() throws {
        let controller = DStreamingMarkdownController()
        controller.update(
            streamID: streamID,
            content: "Контуры ровные.",
            isStreaming: false,
            date: date,
        )
        let previous = try #require(
            controller.blocks.first,
        )
        controller.update(
            streamID: streamID,
            content: "Контуры ровные. Правая доля: 45 × 16 × 17 мм. Левая доля: 43 × 15 × 16 мм. Перешеек: 3 мм. Эхогенность обычная, структура однородная. Очаговые образования не выявлены.",
            isStreaming: true,
            date: date,
        )
        let block = try #require(
            controller.blocks.first,
        )
        let previousView = UIHostingController(
            rootView: DStreamingMarkdownBlockView(
                block: previous,
                date: date,
                textColor: .black,
            ).environmentObject(
                DTheme.light,
            ),
        )
        let previousSize = previousView.sizeThatFits(
            in: CGSize(
                width: 320,
                height: 10000,
            ),
        )
        var sizes: [CGSize] = []
        for (index, elapsed) in [0.0, 0.075, 0.2].enumerated() {
            let view = DStreamingMarkdownBlockView(
                block: block,
                date: date.addingTimeInterval(
                    elapsed,
                ),
                textColor: .black,
            )
            .environmentObject(
                DTheme.light,
            )
            let hosting = UIHostingController(
                rootView: view,
            )
            sizes.append(
                hosting.sizeThatFits(
                    in: CGSize(
                        width: 320,
                        height: 10000,
                    ),
                ),
            )
            let renderer = ImageRenderer(
                content: view.frame(
                    width: 320,
                ).padding(
                    16,
                ).background(
                    Color.white,
                ),
            )
            let image = try #require(
                renderer.uiImage,
            )
            let data = try #require(
                image.pngData(),
            )
            let url = URL(
                filePath: NSTemporaryDirectory(),
            ).appending(
                path: "doglyad-streaming-markdown-\(index).png",
            )
            try data.write(
                to: url,
            )
            print(
                "Streaming Markdown render: \(url.path)",
            )
        }
        #expect(
            sizes[
                0,
            ].height > previousSize.height,
        )
        #expect(
            sizes[
                0,
            ] == sizes[
                1,
            ],
        )
        #expect(
            sizes[
                1,
            ] == sizes[
                2,
            ],
        )
    }

    @Test
    func completedDocumentRendersImmediatelyWithHeadingsListsAndTables() throws {
        let markdown = """
        ### Описание
        Контуры **ровные**, *чёткие*. Размер: `45 мм`.

        1. Правая доля
           - Структура однородная
        2. Левая доля

        | Доля | Размер |
        | --- | --- |
        | Правая | 45 мм |
        | Левая | 43 мм |

        ### Заключение
        Очаговые образования не выявлены.
        """
        let renderer = ImageRenderer(
            content: DStreamingMarkdown(
                streamID: streamID,
                content: markdown,
                isStreaming: false,
            )
            .environmentObject(
                DTheme.light,
            )
            .frame(
                width: 340,
            )
            .padding(
                16,
            )
            .background(
                Color.white,
            ),
        )
        let image = try #require(
            renderer.uiImage,
        )
        #expect(
            image.size.height > 250,
        )
        let url = URL(
            filePath: NSTemporaryDirectory(),
        ).appending(
            path: "doglyad-streaming-markdown-document.png",
        )
        try #require(
            image.pngData(),
        ).write(
            to: url,
        )
        print(
            "Streaming Markdown document: \(url.path)",
        )
    }
}
