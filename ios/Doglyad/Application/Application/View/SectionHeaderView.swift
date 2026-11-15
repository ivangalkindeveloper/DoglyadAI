import DoglyadUI
import SwiftUI

struct SectionHeaderView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    private let title: SectionHeaderTitle

    init(
        title: LocalizedStringResource,
    ) {
        self.title = .localized(
            title,
        )
    }

    init(
        title: String,
    ) {
        self.title = .verbatim(
            title,
        )
    }

    var body: some View {
        HStack(
            spacing: .zero,
        ) {
            SectionHeaderTitleView(
                title: title,
            )
            .padding(
                .horizontal,
                size.s12,
            )
            .padding(
                .vertical,
                size.s8,
            )
            .background(
                DCardBackground(
                    cornerRadius: size.s48,
                    color: color.grayscaleBackgroundWeak.opacity(
                        0.5,
                    ),
                    material: .ultraThinMaterial,
                ),
            )

            Spacer(
                minLength: .zero,
            )
        }
        .padding(
            .vertical,
            size.s4,
        )
        .padding(
            .bottom,
            size.s4,
        )
        .frame(
            maxWidth: .infinity,
        )
    }
}

private enum SectionHeaderTitle {
    case localized(LocalizedStringResource)
    case verbatim(String)
}

private struct SectionHeaderTitleView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    private let title: SectionHeaderTitle

    init(
        title: SectionHeaderTitle,
    ) {
        self.title = title
    }

    var body: some View {
        switch title {
        case let .localized(
            value,
        ):
            DText(
                value,
            )
            .dStyle(
                font: typography.linkXSmall,
            )
        case let .verbatim(
            value,
        ):
            DText(
                value,
            )
            .dStyle(
                font: typography.linkXSmall,
            )
        }
    }
}
