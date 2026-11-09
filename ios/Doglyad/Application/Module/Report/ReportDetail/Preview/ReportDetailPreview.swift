#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ReportDetailContentState SavedReport",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ReportDetailContentState SavedReport ScrollEnd",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 ReportDetailGenerationLoadingState RegeneratingReport",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailGenerationLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ReportDetailGenerationLoadingState RegeneratingReport ScrollEnd",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailGenerationLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 ReportDetailErrorState ReportOperationFailed",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 ReportDetailErrorState ReportOperationFailed ScrollEnd",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "07 ReportDetailExpandableMarkdownView ExpandableMarkdown",
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
        "08 ReportDetailExpandableTextPreviewView OneLine",
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
        "09 ReportDetailExpandableTextPreviewView ThreeLines",
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
        "10 ReportDetailExpandableTextPreviewView FourLines",
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
        "11 ReportDetailExpandableTextPreviewView LongTextWide",
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
        "12 ReportDetailExpandableTextPreviewView LongTextNarrow",
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
        "13 ReportDetailExpandableTextPreviewView OneLineLimit",
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
        "14 ReportDetailModelReportCardView ModelResponseCard",
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
