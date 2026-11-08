#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ReportDetailContentState",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ReportDetailSaveLoadingState",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailSaveLoadingState(
                candidate: ModulePreviewFactory.report,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 ReportDetailGenerationLoadingState",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailGenerationLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ReportDetailFailedState",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 Раскрываемый Markdown",
    ) {
        VStack(
            alignment: .leading,
            spacing: 24,
        ) {
            ReportDetailExpandableMarkdownView(
                text: "**Описание исследования:** без особенностей.",
                backgroundColor: .white,
            )

            ReportDetailExpandableMarkdownView(
                text: ExpandableContentPreviewFixture(
                    scenario: .markdown,
                ).text,
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
        "06 Одна строка — лимит 3",
        traits: .sizeThatFitsLayout,
    ) {
        ReportDetailExpandableTextPreviewView(
            scenario: .short,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "07 Три строки — лимит 3",
        traits: .sizeThatFitsLayout,
    ) {
        ReportDetailExpandableTextPreviewView(
            scenario: .threeLines,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "08 Четыре строки — лимит 3",
        traits: .sizeThatFitsLayout,
    ) {
        ReportDetailExpandableTextPreviewView(
            scenario: .fourLines,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "09 Длинный текст — ширина 360",
        traits: .sizeThatFitsLayout,
    ) {
        ReportDetailExpandableTextPreviewView(
            scenario: .long,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "10 Длинный текст — ширина 260",
        traits: .sizeThatFitsLayout,
    ) {
        ReportDetailExpandableTextPreviewView(
            scenario: .narrow,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "11 Длинный текст — лимит 1",
        traits: .sizeThatFitsLayout,
    ) {
        ReportDetailExpandableTextPreviewView(
            scenario: .singleLineLimit,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "12 Карточка ответа модели",
    ) {
        ReportDetailModelReportCardView(
            report: ModulePreviewFactory.report.actualModelReport,
            onTapCopy: {},
        )
        .padding()
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
