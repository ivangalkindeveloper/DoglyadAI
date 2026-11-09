#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ReadyMadeTemplateListLoadingState LoadingCatalog",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ReadyMadeTemplateListLoadingState LoadingCatalog ScrollEnd",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 ReadyMadeTemplateListErrorState CatalogRequestFailed",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ReadyMadeTemplateListSuccessState EmptyCatalog",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListSuccessState(
                templates: [],
            ),
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 ReadyMadeTemplateListSuccessState AvailableTemplates",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListSuccessState(
                templates: ModulePreviewFactory.readyMadeTemplates,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 ReadyMadeTemplateListSuccessState AvailableTemplates ScrollEnd",
    ) {
        ReadyMadeTemplateListPreviewView(
            state: ReadyMadeTemplateListSuccessState(
                templates: ModulePreviewFactory.readyMadeTemplates,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "07 ReadyMadeTemplateListExpandableTextView ExpandableTemplate",
    ) {
        VStack(
            alignment: .leading,
            spacing: 24,
        ) {
            ReadyMadeTemplateListExpandableTextView(
                text: "Описание исследования: буквальные **звёздочки** остаются текстом.",
                backgroundColor: .white,
            )

            ReadyMadeTemplateListExpandableTextView(
                text: ModulePreviewFactory.readyMadeTemplate.content,
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
        "08 ReadyMadeTemplateListItemCardView ReadyMadeTemplateCard",
    ) {
        ReadyMadeTemplateListItemCardView(
            template: ModulePreviewFactory.readyMadeTemplate,
            examinationTypeTitle: ModulePreviewFactory.examinationType.localizedTitle,
            action: {},
        )
        .padding()
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
