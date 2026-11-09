#if DEBUG
    import DoglyadUI
    import SwiftUI

    struct ExpandableContentPreviewView: DViewProtocol {
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
            ExpandableContentView(
                text: fixture.text,
                backgroundColor: color.grayscaleInput,
                collapsedLineLimit: fixture.collapsedLineLimit,
                onTapContent: nil,
            ) {
                if fixture.isMarkdown {
                    DMarkdown(
                        content: fixture.text,
                    )
                } else {
                    DText(
                        fixture.text,
                    )
                    .dStyle(
                        font: typography.textMedium,
                        color: color.grayscaleHeader,
                        alignment: .leading,
                    )
                    .lineSpacing(
                        16 * 0.15,
                    )
                }
            }
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
                    cornerRadius: size.cardCornerRadius,
                    color: color.grayscaleInput,
                )
            }
            .padding(
                size.s16,
            )
        }
    }

#endif
