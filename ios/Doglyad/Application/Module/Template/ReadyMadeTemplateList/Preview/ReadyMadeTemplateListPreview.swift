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
            state: ReadyMadeTemplateListSuccessState(
                templates: [],
            ),
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ReadyMadeTemplateListSuccessState",
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
        "05 Раскрываемый текст шаблона",
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
        "06 Карточка готового шаблона",
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
