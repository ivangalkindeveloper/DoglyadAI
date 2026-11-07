#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ReadyMadeTemplateListLoadingState",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ReadyMadeTemplateListFailedState",
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
        "03 Каталог пуст",
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

    #Preview(
        "04 ReadyMadeTemplateListContentState",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListContentState(
                templates: ModulePreviewFactory.readyMadeTemplates,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 Раскрываемый текст шаблона",
    ) {
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

    #Preview(
        "06 Карточка готового шаблона",
    ) {
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
#endif
