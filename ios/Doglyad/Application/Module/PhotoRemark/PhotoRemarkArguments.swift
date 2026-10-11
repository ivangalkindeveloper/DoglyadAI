import Router

final class PhotoRemarkArguments: RouteArgumentsProtocol {
    let title: String
    let description: String

    init(
        title: String,
        description: String,
    ) {
        self.title = title
        self.description = description
    }
}
