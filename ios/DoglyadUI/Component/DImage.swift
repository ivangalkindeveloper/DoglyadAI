import SwiftUI

public struct DImage: View {
    private enum Source {
        case resource(ImageResource)
        case photo(UIImage)
    }

    private let source: Source

    public init(
        _ resource: ImageResource,
    ) {
        source = .resource(
            resource,
        )
    }

    public init(
        uiImage: UIImage,
    ) {
        source = .photo(
            uiImage,
        )
    }

    public var body: some View {
        switch source {
        case let .resource(
            resource,
        ):
            Image(
                resource,
            ).resizable()
        case let .photo(
            photo,
        ):
            Image(
                uiImage: photo,
            ).resizable()
        }
    }
}
