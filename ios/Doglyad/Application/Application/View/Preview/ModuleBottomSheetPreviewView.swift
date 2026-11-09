#if DEBUG
    import DoglyadUI
    import SwiftUI

    /// Present sheets at their real detent instead of stretching them across Canvas.
    struct ModuleBottomSheetPreviewView<Content: View>: DViewProtocol {
        @EnvironmentObject var theme: DTheme
        @Environment(
            \.isPreviewScrollEnd,
        ) private var isPreviewScrollEnd
        @State private var isPresented = true
        let content: Content

        init(
            @ViewBuilder content: () -> Content,
        ) {
            self.content = content()
        }

        var body: some View {
            DCardBackground(
                cornerRadius: .zero,
                color: color.grayscaleBackground,
            )
            .ignoresSafeArea()
            .sheet(
                isPresented: $isPresented,
            ) {
                #if DOGLYAD_REGRESSION
                    // A sheet hides its presenting view from the accessibility tree.
                    content
                        .overlay(
                            alignment: .topLeading,
                        ) {
                            if isPreviewScrollEnd {
                                PreviewScrollEndView()
                                    .frame(
                                        width: 1,
                                        height: 1,
                                    )
                                    .allowsHitTesting(
                                        false,
                                    )
                            }
                        }
                        .accessibilityElement(
                            children: .contain,
                        )
                        .accessibilityIdentifier(
                            "regression.\(UserDefaults.standard.string(forKey: "regressionPreview") ?? "unknown")",
                        )
                #else
                    content
                        .overlay(
                            alignment: .topLeading,
                        ) {
                            if isPreviewScrollEnd {
                                PreviewScrollEndView()
                                    .frame(
                                        width: 1,
                                        height: 1,
                                    )
                                    .allowsHitTesting(
                                        false,
                                    )
                            }
                        }
                #endif
            }
        }
    }
#endif
