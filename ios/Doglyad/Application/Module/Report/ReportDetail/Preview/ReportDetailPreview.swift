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
        "02 ReportDetailLoadingState",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailLoadingState(
                candidate: ModulePreviewFactory.report,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 ReportDetailGeneratingState",
    ) {
        ReportDetailPreviewView(
            state: ReportDetailGeneratingState(),
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
                text: "Short **Markdown** content.",
                backgroundColor: .white,
            )

            ReportDetailExpandableMarkdownView(
                text: """
                This is **long** Markdown content that should be truncated after several lines. \
                The expanded view shows all markup. The collapsed view shows a gradient and an expand button. \
                Short content remains fully visible without an expand or collapse button.
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
            report: USExaminationModelReport(
                date: Date(),
                modelId: "google/medgemma-1.5-4b-it",
                description: "The thyroid is normally positioned with homogeneous parenchyma and smooth contours.",
                conclusion: "No sonographic evidence of focal thyroid lesions.",
                recommendations: "Routine follow-up when clinically indicated.",
            ),
            onTapCopy: {},
        )
        .padding()
        .dThemeWrapper()
        .localization(
            DependencyContainer.previewable.l10n,
        )
    }
#endif
