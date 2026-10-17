public protocol DHttpErrorProtocol: Error {}

public class DHttpApiError: DHttpErrorProtocol {}

public class DHttpConnectionError: DHttpErrorProtocol {}
