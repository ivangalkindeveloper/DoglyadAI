import Foundation
import Router

final class TemplateEditScreenArguments: RouteArgumentsProtocol {
    let templateId: UUID
    let onTemplatesChanged: (() -> Void)?

    init(
        templateId: UUID,
        onTemplatesChanged: (() -> Void)? = nil
    ) {
        self.templateId = templateId
        self.onTemplatesChanged = onTemplatesChanged
    }
}
