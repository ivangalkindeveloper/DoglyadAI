#if DEBUG
    import DoglyadUI
    import SwiftUI

    struct PreviewMessageModifier: ViewModifier {
        @EnvironmentObject private var messager: DMessager
        @EnvironmentObject private var container: DependencyContainer
        let type: DMessageType
        let title: L10NKey?
        let description: L10NKey?

        init(
            type: DMessageType,
            title: L10NKey?,
            description: L10NKey?,
        ) {
            self.type = type
            self.title = title
            self.description = description
        }

        func body(
            content: Content,
        ) -> some View {
            content.task(
                id: title,
            ) {
                guard let title else {
                    return
                }
                do {
                    try await Task.sleep(
                        for: .seconds(
                            1,
                        ),
                    )
                } catch {
                    return
                }
                messager.show(
                    type: type,
                    title: container.l10n[
                        title,
                    ],
                    description: description.map {
                        container.l10n[
                            $0,
                        ]
                    },
                )
            }
        }
    }
#endif
