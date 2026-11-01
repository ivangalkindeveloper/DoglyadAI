internal import SwiftMessages
import Foundation

struct DMessage: Identifiable, Equatable {
    var id: String {
        "\(type) \(title) \(description ?? "")"
    }

    let type: DMessageType
    let title: LocalizedStringResource
    let description: LocalizedStringResource?
}
