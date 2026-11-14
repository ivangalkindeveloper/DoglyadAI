internal import SwiftMessages
import Foundation

struct DMessage: Identifiable, Equatable {
    var id: String {
        "\(type) \(title) \(description ?? "")"
    }

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
}
