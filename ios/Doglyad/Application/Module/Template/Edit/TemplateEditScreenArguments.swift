import Foundation
import Router

final class TemplateEditScreenArguments: RouteArgumentsProtocol {
    let templateId: UUID

    init(
        templateId: UUID
    ) {
        self.templateId = templateId
    }
}
