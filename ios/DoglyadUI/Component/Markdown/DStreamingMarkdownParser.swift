internal import cmark_gfm
internal import cmark_gfm_extensions
import Foundation

enum DStreamingMarkdownParser {
    private typealias Node = UnsafeMutablePointer<cmark_node>
    private typealias Content = DStreamingMarkdownBlock.Content
    private typealias Inline = Content.Inline

    static func parse(
        _ markdown: String,
    ) -> [DStreamingMarkdownBlock.Content] {
        guard !markdown.isEmpty else {
            return []
        }
        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(
            CMARK_OPT_DEFAULT,
        ) else {
            return [Content(
                kind: .fallback,
                markdown: markdown,
                inlines: [],
            )]
        }
        defer {
            cmark_parser_free(
                parser,
            )
        }
        for name in ["autolink", "strikethrough", "tagfilter", "tasklist", "table"] {
            if let syntax = cmark_find_syntax_extension(
                name,
            ) {
                cmark_parser_attach_syntax_extension(
                    parser,
                    syntax,
                )
            }
        }
        cmark_parser_feed(
            parser,
            markdown,
            markdown.utf8.count,
        )
        guard let document = cmark_parser_finish(
            parser,
        ) else {
            return [Content(
                kind: .fallback,
                markdown: markdown,
                inlines: [],
            )]
        }
        defer {
            cmark_node_free(
                document,
            )
        }
        return children(
            of: document,
        ).flatMap {
            blocks(
                from: $0,
            )
        }
    }

    private static func blocks(
        from node: Node,
    ) -> [Content] {
        let type = nodeType(
            node,
        )
        if type == "list", !contains(
            node,
            types: ["tasklist"],
        ) {
            var result: [Content] = []
            let isOrdered = cmark_node_get_list_type(
                node,
            ) == CMARK_ORDERED_LIST
            let start = Int(
                cmark_node_get_list_start(
                    node,
                ),
            )
            let isTight = cmark_node_get_list_tight(
                node,
            ) != 0
            for (index, item) in children(
                of: node,
            ).enumerated() {
                var itemBlocks = children(
                    of: item,
                ).flatMap {
                    blocks(
                        from: $0,
                    )
                }
                for offset in itemBlocks.indices {
                    itemBlocks[
                        offset,
                    ].indent += 1
                    if isTight {
                        itemBlocks[
                            offset,
                        ].bottomMargin = 0
                    }
                }
                if !itemBlocks.isEmpty {
                    let delimiter = cmark_node_get_list_delim(
                        node,
                    ) == CMARK_PAREN_DELIM ? ")" : "."
                    itemBlocks[
                        0,
                    ].marker = isOrdered ? "\(start + index)\(delimiter)" : "•"
                }
                result.append(
                    contentsOf: itemBlocks,
                )
            }
            if let last = result.indices.last {
                result[
                    last,
                ].bottomMargin = 16
            }
            return result
        }

        let markdown = serialized(
            node,
        )
        if ["paragraph", "heading"].contains(
            type,
        ), !contains(
            node,
            types: ["image", "html_inline"],
        ) {
            let isHeading = type == "heading"
            return [Content(
                kind: isHeading ? .heading(
                    Int(
                        cmark_node_get_heading_level(
                            node,
                        ),
                    ),
                ) : .paragraph,
                markdown: markdown,
                inlines: children(
                    of: node,
                ).flatMap {
                    inlines(
                        from: $0,
                        style: [],
                        link: nil,
                    )
                },
                topMargin: isHeading ? 24 : 0,
                bottomMargin: isHeading ? 8 : 16,
            )]
        }
        return [Content(
            kind: .fallback,
            markdown: markdown,
            inlines: [],
            topMargin: type == "thematic_break" ? 32 : 0,
            bottomMargin: type == "thematic_break" ? 32 : 16,
        )]
    }

    private static func inlines(
        from node: Node,
        style: Inline.Style,
        link: URL?,
    ) -> [Inline] {
        switch nodeType(
            node,
        ) {
        case "text", "code":
            return [Inline(
                text: cmark_node_get_literal(
                    node,
                ).map {
                    String(
                        cString: $0,
                    )
                } ?? "",
                style: nodeType(
                    node,
                ) == "code" ? style.union(
                    .code,
                ) : style,
                link: link,
            )]
        case "softbreak", "linebreak":
            return [Inline(
                text: nodeType(
                    node,
                ) == "linebreak" ? "\n" : " ",
                style: style,
                link: link,
            )]
        default:
            var nestedStyle = style
            var nestedLink = link
            switch nodeType(
                node,
            ) {
            case "strong":
                nestedStyle.insert(
                    .strong,
                )
            case "emph":
                nestedStyle.insert(
                    .emphasis,
                )
            case "strikethrough":
                nestedStyle.insert(
                    .strikethrough,
                )
            case "link":
                nestedLink = cmark_node_get_url(
                    node,
                ).flatMap {
                    URL(
                        string: String(
                            cString: $0,
                        ),
                    )
                }
            default: break
            }
            return children(
                of: node,
            ).flatMap {
                inlines(
                    from: $0,
                    style: nestedStyle,
                    link: nestedLink,
                )
            }
        }
    }

    private static func children(
        of node: Node,
    ) -> [Node] {
        var result: [Node] = []
        var child = cmark_node_first_child(
            node,
        )
        while let current = child {
            result.append(
                current,
            )
            child = cmark_node_next(
                current,
            )
        }
        return result
    }

    private static func contains(
        _ node: Node,
        types: Set<String>,
    ) -> Bool {
        types.contains(
            nodeType(
                node,
            ),
        ) || children(
            of: node,
        ).contains {
            contains(
                $0,
                types: types,
            )
        }
    }

    private static func nodeType(
        _ node: Node,
    ) -> String {
        String(
            cString: cmark_node_get_type_string(
                node,
            ),
        )
    }

    private static func serialized(
        _ node: Node,
    ) -> String {
        guard let value = cmark_render_commonmark(
            node,
            CMARK_OPT_DEFAULT,
            0,
        ) else {
            return ""
        }
        defer {
            free(
                value,
            )
        }
        return String(
            cString: value,
        ).trimmingCharacters(
            in: .newlines,
        )
    }
}
