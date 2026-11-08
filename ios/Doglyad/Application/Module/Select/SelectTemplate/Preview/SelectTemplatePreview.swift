#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectTemplateTemplatesLoadingState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateTemplatesLoadingState(),
            templates: [],
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectTemplateFailedState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
            templates: [],
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 SelectTemplateEmptyState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateEmptyState(),
            templates: [],
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SelectTemplateContentState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateContentState(),
            templates: [ModulePreviewFactory.template],
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 Применение выбранного шаблона",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateSelectionLoadingState(),
            templates: [ModulePreviewFactory.template],
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
