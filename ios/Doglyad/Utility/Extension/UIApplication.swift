import UIKit

extension UIApplication {
    static func openSettings() {
        guard let settingsURL = URL(
            string: openSettingsURLString,
        ) else { return }
        guard shared.canOpenURL(
            settingsURL,
        ) else { return }
        shared.open(
            settingsURL,
        )
    }

    static func openAppStore(
        appleUpdateUrl: URL,
        id: String,
    ) {
        let url = appleUpdateUrl.appendingPathComponent(
            id,
        )
        guard shared.canOpenURL(
            url,
        ) else { return }
        shared.open(
            url,
        )
    }

    static func openMail(
        subject: String,
        body: String,
    ) {
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~",
        )
        let encodedSubject = subject.addingPercentEncoding(
            withAllowedCharacters: allowed,
        ) ?? ""
        let encodedBody = body.addingPercentEncoding(
            withAllowedCharacters: allowed,
        ) ?? ""
        guard let url = URL(
            string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)",
        ) else { return }
        shared.open(
            url,
        )
    }

    static func pasteboard(
        _ string: String,
    ) {
        UIPasteboard.general.string = string
    }
}
