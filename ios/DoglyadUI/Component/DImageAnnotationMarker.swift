import SwiftUI

public struct DImageAnnotationMarker: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    let title: String
    let action: () -> Void
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        title: String,
        action: @escaping () -> Void,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.title = title

        self.action = action
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            DTextButton(
                action: action,
            ) {
                Circle()
                    .fill(
                        color.primaryDefault,
                    )
                    .overlay {
                        Circle().strokeBorder(
                            color.grayscaleBackground,
                            lineWidth: size.s1,
                        )
                    }
                    .frame(
                        width: size.s12,
                        height: size.s12,
                    )
                    .overlay(
                        alignment: .top,
                    ) {
                        DImageAnnotationMarkerTitleLayout(
                            maximumWidth: size.s64 * 3,
                        ) {
                            DText(
                                title,
                            )
                            .dStyle(
                                font: typography.textSmall,
                                color: color.grayscaleBackground,
                                alignment: .center,
                            )
                            .lineLimit(
                                2,
                            )
                        }
                        .padding(
                            .horizontal,
                            size.s8,
                        )
                        .padding(
                            .vertical,
                            size.s4,
                        )
                        .background(
                            DCardBackground(
                                cornerRadius: size.s8,
                                material: .ultraThinMaterial,
                            ),
                        )
                        .alignmentGuide(
                            .top,
                        ) { dimensions in
                            dimensions.height + size.s8
                        }
                    }
                    .frame(
                        width: size.s48,
                        height: size.s48,
                    )
                    .contentShape(
                        Circle(),
                    )
            }
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}

// Measure the title independently of the marker's small layout proposal.
private struct DImageAnnotationMarkerTitleLayout: Layout {
    let maximumWidth: CGFloat

    func sizeThatFits(
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout (),
    ) -> CGSize {
        subviews[
            0,
        ].sizeThatFits(
            ProposedViewSize(
                width: maximumWidth,
                height: nil,
            ),
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout (),
    ) {
        subviews[
            0,
        ].place(
            at: bounds.origin,
            proposal: ProposedViewSize(
                width: maximumWidth,
                height: nil,
            ),
        )
    }
}
