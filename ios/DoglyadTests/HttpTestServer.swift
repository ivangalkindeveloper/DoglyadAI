import Foundation
import Network

final class HttpTestServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(
        label: "DoglyadTests.HttpTestServer",
    )
    private let lock = NSLock()
    private var targets: [String] = []

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: "127.0.0.1",
            port: .any,
        )
        listener = try NWListener(
            using: parameters,
        )
    }

    var receivedTargets: [String] {
        lock.withLock {
            targets
        }
    }

    func start() async throws -> String {
        listener.newConnectionHandler = { [weak self, queue] connection in
            guard let self else {
                return
            }
            connection.start(
                queue: queue,
            )
            receive(
                connection,
                buffered: Data(),
            )
        }
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume(
                        returning: "http://127.0.0.1:\(listener.port!.rawValue)",
                    )
                case let .failed(
                    error,
                ):
                    listener.stateUpdateHandler = nil
                    continuation.resume(
                        throwing: error,
                    )
                default: break
                }
            }
            listener.start(
                queue: queue,
            )
        }
    }

    func stop() {
        listener.cancel()
    }

    private func receive(
        _ connection: NWConnection,
        buffered: Data,
    ) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65536,
        ) { data, _, isComplete, error in
            let combined = buffered + (data ?? Data())
            let text = String(
                decoding: combined,
                as: UTF8.self,
            )
            guard let end = text.range(
                of: "\r\n\r\n",
            ) else {
                if isComplete || error != nil {
                    connection.cancel()
                } else {
                    self.receive(
                        connection,
                        buffered: combined,
                    )
                }
                return
            }
            let lines = text[
                ..<end.lowerBound,
            ].components(
                separatedBy: "\r\n",
            ).dropFirst()
            var headers: [String: String] = [:]
            for line in lines {
                let parts = line.split(
                    separator: ":",
                    maxSplits: 1,
                )
                if parts.count == 2 {
                    headers[
                        parts[
                            0,
                        ].lowercased(),
                    ] = parts[
                        1,
                    ].trimmingCharacters(
                        in: .whitespaces,
                    )
                }
            }
            let bodyLength = Int(
                headers[
                    "content-length",
                ] ?? "0",
            ) ?? 0
            let requestBody = Data(
                combined.dropFirst(
                    text[
                        ..<end.upperBound,
                    ].utf8.count,
                ),
            )
            guard requestBody.count >= bodyLength else {
                self.receive(
                    connection,
                    buffered: combined,
                )
                return
            }
            let target = text.components(
                separatedBy: "\r\n",
            )[
                0,
            ].split(
                separator: " ",
            )[
                1,
            ]
            self.lock.withLock {
                self.targets.append(
                    String(
                        target,
                    ),
                )
            }
            let payload = [
                "contentType": headers[
                    "content-type",
                ] ?? "missing",
                "custom": headers[
                    "x-test",
                ] ?? "missing",
                "target": String(
                    target,
                ),
                "body": requestBody.base64EncodedString(),
            ]
            let json = try! JSONEncoder().encode(
                payload,
            )
            let isStream = headers[
                "accept",
            ] == "text/event-stream"
            let body = isStream ? Data(
                "data: ".utf8,
            ) + json + Data(
                "\n\n".utf8,
            ) : json
            let contentType = isStream ? "text/event-stream" : "application/json"
            let head = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
            connection.send(
                content: Data(
                    head.utf8,
                ) + body,
                completion: .contentProcessed { _ in
                    connection.cancel()
                },
            )
        }
    }
}
