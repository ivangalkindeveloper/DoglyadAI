import Router

final class ImportMediaArguments: RouteArgumentsProtocol {
    let onTapCamera: () -> Void
    let onTapGallery: () -> Void

    init(
        onTapCamera: @escaping () -> Void,
        onTapGallery: @escaping () -> Void
    ) {
        self.onTapCamera = onTapCamera
        self.onTapGallery = onTapGallery
    }
}
