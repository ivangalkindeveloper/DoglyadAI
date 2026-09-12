import DoglyadUI
import SwiftUI

struct SectionHeaderView: View {
    private enum Title {
        case localized(LocalizedStringResource)
        case verbatim(String)
    }

    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    private let title: Title

    init(title: LocalizedStringResource) {
        self.title = .localized(title)
    }

    init(title: String) {
        self.title = .verbatim(title)
    }

    var body: some View {
        HStack(spacing: .zero) {
            titleView
                .padding(.horizontal, size.s12)
                .padding(.vertical, size.s8)
                .background(
                    Capsule()
                        .fill(color.grayscaleBackgroundWeak.opacity(0.5))
                        .fill(.ultraThinMaterial)
                )

            Spacer(minLength: .zero)
        }
        .padding(.vertical, size.s4)
        .padding(.bottom, size.s4)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var titleView: some View {
        switch title {
        case let .localized(value):
            DText(value)
                .dStyle(
                    font: typography.linkXSmall
                )
        case let .verbatim(value):
            DText(value)
                .dStyle(
                    font: typography.linkXSmall
                )
        }
    }
}
