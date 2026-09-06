import Foundation
import UIKit

@MainActor
final class ErrorViewModel: ObservableObject {
    let email: String?

    init(
        email: String?
    ) {
        self.email = email
    }

    func onTapEmail() {
        guard let email else { return }
        guard let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        guard let url = URL(string: "mailto:\(encodedEmail)") else { return }
        UIApplication.shared.open(url)
    }
}
