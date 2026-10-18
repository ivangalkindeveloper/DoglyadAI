import DoglyadUI
import SwiftUI

struct ReportDetailExpandableTextView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    let text: String
    let backgroundColor: Color
    let collapsedLineLimit: Int

    init(
        text: String,
        backgroundColor: Color,
        collapsedLineLimit: Int = 3,
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.collapsedLineLimit = collapsedLineLimit
    }

    var body: some View {
        ExpandableContentView(
            text: text,
            backgroundColor: backgroundColor,
            collapsedLineLimit: collapsedLineLimit,
            collapsedFontSize: 14,
            collapsedLineSpacing: 0,
            onTapContent: nil,
        ) {
            DText(
                text,
            )
            .dStyle(
                font: typography.textSmall,
                alignment: .leading,
            )
        }
    }
}

#if DEBUG
    private struct ReportDetailExpandableTextPreviewView: DViewProtocol {
        @EnvironmentObject var theme: DTheme

        private let fixture: ExpandableContentPreviewFixture
        let scenario: ExpandableContentPreviewFixture.Scenario

        init(
            scenario: ExpandableContentPreviewFixture.Scenario,
        ) {
            fixture = ExpandableContentPreviewFixture(
                scenario: scenario,
            )
            self.scenario = scenario
        }

        var body: some View {
            ReportDetailExpandableTextView(
                text: fixture.text,
                backgroundColor: color.grayscaleBackgroundWeak,
                collapsedLineLimit: fixture.collapsedLineLimit,
            )
            .id(
                scenario,
            )
            .padding(
                size.s16,
            )
            .frame(
                width: fixture.width,
                alignment: .leading,
            )
            .background {
                DCardBackground(
                    cornerRadius: size.s16,
                    color: color.grayscaleBackgroundWeak,
                )
            }
            .padding(
                size.s16,
            )
        }
    }

    #Preview(
        "Одна строка — лимит 3",
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
        "Три строки — лимит 3",
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
        "Четыре строки — лимит 3",
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
        "Длинный текст — ширина 360",
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
        "Длинный текст — ширина 260",
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
        "Длинный текст — лимит 1",
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
#endif
