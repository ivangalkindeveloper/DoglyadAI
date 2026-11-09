import Combine
import Foundation

@MainActor
final class DStreamingMarkdownController: ObservableObject {
    @Published private(set) var blocks: [DStreamingMarkdownBlock] = []
    @Published private(set) var animationEnd: Date?
    private var streamID: UUID?
    private var content = ""
    private var isStreaming = false

    init(
        streamID: UUID? = nil,
        content: String = "",
        isStreaming: Bool = false,
    ) {
        let date = Date()
        blocks = DStreamingMarkdownParser.parse(
            content,
        ).map { item in
            DStreamingMarkdownBlock(
                id: UUID(),
                content: item,
                reveals: isStreaming && !item.text.isEmpty ? [.init(
                    range: 0 ..< item.text.count,
                    date: date,
                )] : [],
            )
        }
        animationEnd = blocks.contains {
            !$0.reveals.isEmpty
        } ? date.addingTimeInterval(
            DStreamingMarkdownBlock.Reveal.duration,
        ) : nil
        self.streamID = streamID
        self.content = content
        self.isStreaming = isStreaming
    }

    func update(
        streamID: UUID,
        content: String,
        isStreaming: Bool,
        date: Date = Date(),
    ) {
        guard self.streamID != streamID || self.content != content || self.isStreaming != isStreaming else {
            return
        }
        let previous = self.streamID == streamID ? blocks : []
        self.streamID = streamID
        self.content = content
        self.isStreaming = isStreaming
        let parsed = DStreamingMarkdownParser.parse(
            content,
        )
        let matches = matchingIndices(
            parsed,
            previous: previous,
        )
        blocks = parsed.enumerated().map { index, item in
            let old = matches[
                index,
            ].map {
                previous[
                    $0,
                ]
            }
            return DStreamingMarkdownBlock(
                id: old?.id ?? UUID(),
                content: item,
                reveals: isStreaming ? reveals(
                    for: item,
                    previous: old,
                    date: date,
                ) : [],
            )
        }
        animationEnd = blocks.flatMap(
            \.reveals,
        ).map {
            $0.date.addingTimeInterval(
                DStreamingMarkdownBlock.Reveal.duration,
            )
        }.max()
    }

    func finishAnimation() async {
        guard let deadline = animationEnd else {
            return
        }
        do {
            try await Task.sleep(
                for: .seconds(
                    max(
                        0,
                        deadline.timeIntervalSinceNow,
                    ),
                ),
            )
        } catch {
            return
        }
        guard !Task.isCancelled, animationEnd == deadline else {
            return
        }
        animationEnd = nil
    }

    private func matchingIndices(
        _ parsed: [DStreamingMarkdownBlock.Content],
        previous: [DStreamingMarkdownBlock],
    ) -> [Int?] {
        var matches = [Int?](
            repeating: nil,
            count: parsed.count,
        )
        var used = Set<Int>()
        for index in parsed.indices {
            if let match = previous.indices.first(
                where: {
                    !used.contains(
                        $0,
                    ) && previous[
                        $0,
                    ].content == parsed[
                        index,
                    ]
                },
            ) {
                matches[
                    index,
                ] = match
                used.insert(
                    match,
                )
            }
        }
        for index in parsed.indices where matches[
            index,
        ] == nil {
            let lower = matches[
                ..<index,
            ].compactMap(
                \.self,
            ).last.map {
                $0 + 1
            } ?? 0
            let upper = matches[
                (index + 1)...,
            ].compactMap(
                \.self,
            ).first ?? previous.count
            if let match = previous.indices.first(
                where: {
                    $0 >= lower && $0 < upper && !used.contains(
                        $0,
                    ) && previous[
                        $0,
                    ].content.kind == parsed[
                        index,
                    ].kind
                },
            ) {
                matches[
                    index,
                ] = match
                used.insert(
                    match,
                )
            }
        }
        return matches
    }

    private func reveals(
        for content: DStreamingMarkdownBlock.Content,
        previous: DStreamingMarkdownBlock?,
        date: Date,
    ) -> [DStreamingMarkdownBlock.Reveal] {
        let text = content.text
        guard !text.isEmpty else {
            return []
        }
        let oldText = previous?.content.text ?? ""
        // Formatting closures and corrections replace the affected text immediately.
        guard text.hasPrefix(
            oldText,
        ) else {
            return []
        }
        var result = previous?.reveals.filter {
            $0.opacity(
                at: date,
            ) < 1
        } ?? []
        if text.count > oldText.count {
            result.append(
                .init(
                    range: oldText.count ..< text.count,
                    date: date,
                ),
            )
        }
        return result
    }
}
