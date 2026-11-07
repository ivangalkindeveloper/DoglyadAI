import UIKit

extension UIApplication {
    static func openSettings() {
        guard let settingsURL = URL(
            string: openSettingsURLString,
        ) else {
            return
        }
        guard shared.canOpenURL(
            settingsURL,
        ) else {
            return
        }
        shared.open(
            settingsURL,
        )
    }

    static func openAppStore(
        appleUpdateUrl: URL,
        id: String,
    ) {
        // Configuration supplies the App Store prefix ending in /app/id.
        guard let url = URL(
            string: appleUpdateUrl.absoluteString + id,
        ) else {
            return
        }
        #if DEBUG && DOGLYAD_REGRESSION
            if RegressionExternalActions.handle(
                url,
            ) {
                return
            }
        #endif
        guard shared.canOpenURL(
            url,
        ) else {
            return
        }
        shared.open(
            url,
        )
    }

    static func openMail(
        subject: String,
        body: String,
        recipient: String? = nil,
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
        let encodedRecipient = recipient?.addingPercentEncoding(
            withAllowedCharacters: allowed.union(
                CharacterSet(
                    charactersIn: "@+",
                ),
            ),
        ) ?? ""
        guard let url = URL(
            string: "mailto:\(encodedRecipient)?subject=\(encodedSubject)&body=\(encodedBody)",
        ) else {
            return
        }
        #if DEBUG && DOGLYAD_REGRESSION
            if RegressionExternalActions.handle(
                url,
            ) {
                return
            }
        #endif
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
