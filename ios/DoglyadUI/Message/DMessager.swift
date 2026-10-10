import Combine
import SwiftUI

public final class DMessager: ObservableObject {
    @Published var message: DMessage?

    public func show(
        type: DMessageType,
        title: LocalizedStringResource,
        description: LocalizedStringResource? = nil,
    ) {
        message = DMessage(
            type: type,
            title: title,
            description: description,
        )
    }

    public func hide() {
        message = nil
    }
}
