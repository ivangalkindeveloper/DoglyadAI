#if DEBUG
    import DoglyadUI
    import SwiftUI

    /// Present sheets at their real detent instead of stretching them across Canvas.
    struct ModuleBottomSheetPreviewView<Content: View>: DViewProtocol {
        @EnvironmentObject var theme: DTheme
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
                content
            }
        }
    }
#endif
