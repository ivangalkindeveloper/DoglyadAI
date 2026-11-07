#if DEBUG && DOGLYAD_REGRESSION
    import Foundation
    import UIKit

    /// Replaces only the unavailable external application, never a billing provider.
    @MainActor
    enum RegressionExternalActions {
        static func handle(
            _ url: URL,
        ) -> Bool {
            guard UserDefaults.standard.bool(
                forKey: "regressionExternalApps",
            ),
                url.scheme == "mailto" || url.host == "apps.apple.com"
            else {
                return false
            }
            Task { @MainActor in
                try? await Task.sleep(
                    for: .milliseconds(
                        600,
                    ),
                )
                guard let scene = UIApplication.shared.connectedScenes.compactMap(
                    {
                        $0 as? UIWindowScene
                    },
                ).first(
                    where: {
                        $0.activationState == .foregroundActive
                    },
                ),
                    var presenter = scene.windows.first(
                        where: \.isKeyWindow,
                    )?.rootViewController
                else {
                    return
                }
                while let next = presenter.presentedViewController {
                    presenter = next
                }
                let alert = UIAlertController(
                    title: "Внешнее приложение — тестовый адаптер",
                    message: url.scheme == "mailto" ? "Почтовый клиент" : "App Store",
                    preferredStyle: .alert,
                )
                alert.addAction(
                    UIAlertAction(
                        title: "Отмена",
                        style: .cancel,
                    ) { _ in
                        do {
                            let folder = URL.documentsDirectory.appendingPathComponent(
                                "RegressionExternalActions",
                            )
                            try FileManager.default.createDirectory(
                                at: folder,
                                withIntermediateDirectories: true,
                            )
                            let data = try JSONSerialization.data(
                                withJSONObject: ["url": url.absoluteString, "canceled": true, "adapter": "external-application"],
                            )
                            try data.write(
                                to: folder.appendingPathComponent(
                                    UUID().uuidString + ".json",
                                ),
                                options: .atomic,
                            )
                        } catch {
                            assertionFailure(
                                "Could not record the external application action",
                            )
                        }
                    },
                )
                presenter.present(
                    alert,
                    animated: true,
                )
            }
            return true
        }
    }
#endif
