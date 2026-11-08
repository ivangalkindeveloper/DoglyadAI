#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 Шаблон",
        traits: .sizeThatFitsLayout,
    ) {
        TemplateListItemCardView(
            template: ModulePreviewFactory.template,
            action: {},
        )
        .padding(
            16,
        )
        .dThemeWrapper()
    }

    #Preview(
        "02 Выбранный шаблон",
        traits: .sizeThatFitsLayout,
    ) {
        TemplateListItemCardView(
            template: ModulePreviewFactory.template,
            action: {},
            isSelected: true,
        )
        .padding(
            16,
        )
        .dThemeWrapper()
    }
#endif
