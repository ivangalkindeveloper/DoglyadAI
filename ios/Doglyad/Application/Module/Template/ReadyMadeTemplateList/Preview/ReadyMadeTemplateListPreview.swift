#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "ReadyMadeTemplateListContentState",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListContentState(
                templates: [ModulePreviewFactory.readyMadeTemplate],
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ReadyMadeTemplateListFailedState",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ReadyMadeTemplateListLoadingState",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview {
        VStack(
            alignment: .leading,
            spacing: 24,
        ) {
            ReadyMadeTemplateListExpandableTextView(
                text: "Short plain text, including literal **asterisks**.",
                backgroundColor: .white,
            )

            ReadyMadeTemplateListExpandableTextView(
                text: """
                This is long plain text that should be truncated after several lines. \
                Markdown characters such as **bold** and [links](https://example.com) remain literal text. \
                The expanded view shows the entire text, and short content has no expand or collapse button.
                """,
                backgroundColor: .white,
            )
        }
        .padding()
        .dThemeWrapper()
        .localization(
            DependencyContainer.previewable.l10n,
        )
    }

    #Preview {
        ReadyMadeTemplateListItemCardView(
            template: USExaminationReadyMadeTemplate(
                id: "thyroidGlandStandard",
                examinationType: "thyroidGland",
                title: "Thyroid ultrasound",
                content: "**Examination description:**\n\nThe thyroid gland is located in the typical position.",
            ),
            examinationTypeTitle: "Thyroid gland",
            action: {},
        )
        .padding()
        .dThemeWrapper()
    }

    #Preview(
        "Каталог пуст",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListContentState(
                templates: [],
            ),
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
