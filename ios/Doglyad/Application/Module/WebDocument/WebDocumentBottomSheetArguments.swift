import Foundation
import Router

final class WebDocumentBottomSheetArguments: RouteArgumentsProtocol {
    let url: URL
    let title: LocalizedStringResource

    init(
        url: URL,
        title: LocalizedStringResource,
    ) {
        self.url = url
        self.title = title
    }
}
