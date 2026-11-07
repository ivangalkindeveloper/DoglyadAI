import SwiftUI

public struct DStreamingMarkdown: View {
    @StateObject private var controller: DStreamingMarkdownController

    private let streamID: UUID
    private let content: String
    private let isStreaming: Bool
    private let textColor: Color?
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        streamID: UUID,
        content: String,
        isStreaming: Bool,
        textColor: Color? = nil,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        _controller = StateObject(
            wrappedValue: DStreamingMarkdownController(
                streamID: streamID,
                content: content,
                isStreaming: isStreaming,
            ),
        )
        self.streamID = streamID
        self.content = content
        self.isStreaming = isStreaming
        self.textColor = textColor
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 60,
                    paused: controller.animationEnd == nil,
                ),
            ) { context in
                VStack(
                    alignment: .leading,
                    spacing: 0,
                ) {
                    ForEach(
                        Array(
                            controller.blocks.enumerated(),
                        ),
                        id: \.element.id,
                    ) { index, block in
                        DStreamingMarkdownBlockView(
                            block: block,
                            date: controller.animationEnd == nil ? .distantFuture : context.date,
                            textColor: textColor,
                        )
                        .padding(
                            .top,
                            index == 0 ? 0 : max(
                                controller.blocks[
                                    index - 1,
                                ].content.bottomMargin,
                                block.content.topMargin,
                            ),
                        )
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
            }
            .onChange(
                of: streamID,
                initial: true,
            ) { _, _ in
                controller.update(
                    streamID: streamID,
                    content: content,
                    isStreaming: isStreaming,
                )
            }
            .onChange(
                of: content,
            ) { _, _ in
                controller.update(
                    streamID: streamID,
                    content: content,
                    isStreaming: isStreaming,
                )
            }
            .onChange(
                of: isStreaming,
            ) { _, _ in
                controller.update(
                    streamID: streamID,
                    content: content,
                    isStreaming: isStreaming,
                )
            }
            .task(
                id: controller.animationEnd,
            ) {
                await controller.finishAnimation()
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}
