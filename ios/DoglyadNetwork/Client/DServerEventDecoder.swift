import Foundation

struct DServerEventDecoder {
    private var buffer = Data()
    private var dataLines: [String] = []
    private var event = "message"
    private var id: String?
    private var eventBytes = 0
    private let maximumBytes = 4194304

    init() {}

    mutating func append(
        _ data: Data,
    ) throws -> [DServerEvent] {
        buffer.append(
            data,
        )
        var events: [DServerEvent] = []
        while let end = buffer.firstIndex(
            of: 10,
        ) {
            let bytes = buffer[
                ..<end,
            ]
            guard let decoded = String(
                data: bytes,
                encoding: .utf8,
            ) else {
                throw URLError(
                    .cannotDecodeContentData,
                )
            }
            let line = decoded.hasSuffix(
                "\r",
            ) ? String(
                decoded.dropLast(),
            ) : decoded
            buffer.removeSubrange(
                ...end,
            )
            eventBytes += bytes.count
            guard eventBytes <= maximumBytes else {
                throw URLError(
                    .dataLengthExceedsMaximum,
                )
            }
            if line.isEmpty {
                if !dataLines.isEmpty {
                    events.append(
                        DServerEvent(
                            id: id,
                            event: event,
                            data: Data(
                                dataLines.joined(
                                    separator: "\n",
                                ).utf8,
                            ),
                        ),
                    )
                }
                dataLines = []
                event = "message"
                id = nil
                eventBytes = 0
            } else if !line.hasPrefix(
                ":",
            ) {
                let parts = line.split(
                    separator: ":",
                    maxSplits: 1,
                    omittingEmptySubsequences: false,
                )
                let raw = parts.count > 1 ? String(
                    parts[
                        1,
                    ],
                ) : ""
                let value = raw.hasPrefix(
                    " ",
                ) ? String(
                    raw.dropFirst(),
                ) : raw
                switch parts[
                    0,
                ] {
                case "data":
                    dataLines.append(
                        value,
                    )
                case "event": event = value
                case "id": id = value
                default: break
                }
            }
        }
        guard buffer.count + eventBytes <= maximumBytes else {
            throw URLError(
                .dataLengthExceedsMaximum,
            )
        }
        return events
    }

    func finish() throws {
        guard buffer.isEmpty, dataLines.isEmpty else {
            throw URLError(
                .cannotDecodeContentData,
            )
        }
    }
}
