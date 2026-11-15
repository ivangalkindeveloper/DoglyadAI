internal import SwiftMessages
import Foundation

struct DMessage: Identifiable, Equatable {
    let type: DMessageType
    let title: LocalizedStringResource
    let description: LocalizedStringResource?

    init(
        type: DMessageType,
        title: LocalizedStringResource,
        description: LocalizedStringResource?,
    ) {
        self.type = type
        self.title = title
        self.description = description
    }

    var id: String {
        "\(type) \(title) \(description ?? "")"
    }
}
