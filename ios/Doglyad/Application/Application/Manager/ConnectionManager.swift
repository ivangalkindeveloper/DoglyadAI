import Network

protocol ConnectionManagerProtocol: AnyObject {
    func start()

    var isConnected: Bool {
        get
    }

    func stop()
}

final class ConnectionManager: ConnectionManagerProtocol {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(
        qos: .utility,
    )

    init() {
        monitor.pathUpdateHandler = { path in
            _ = path.status
        }
    }

    var isConnected: Bool {
        switch monitor.currentPath.status {
        case .satisfied: true
        case .unsatisfied, .requiresConnection: false
        @unknown default: false
        }
    }

    func start() {
        monitor.start(
            queue: queue,
        )
    }

    func stop() {
        monitor.cancel()
    }
}
