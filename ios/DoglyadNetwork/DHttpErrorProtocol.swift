public protocol DHttpErrorProtocol: Error {}

public class DHttpApiError: DHttpErrorProtocol {
    init() {}
}

public class DHttpConnectionError: DHttpErrorProtocol {
    init() {}
}
