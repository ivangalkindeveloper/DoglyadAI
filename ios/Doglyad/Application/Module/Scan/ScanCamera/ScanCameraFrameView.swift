import DoglyadUI
import SwiftUI

struct ScanCameraFrameView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let onFrameChanged: (CGRect) -> Void

    var body: some View {
        DCaptureFrame()
            .onGeometryChange(
                for: CGRect.self,
            ) { proxy in
                proxy.frame(
                    in: .global,
                )
            } action: { frame in
                onFrameChanged(
                    frame,
                )
            }
            .aspectRatio(
                3.0 / 2.0,
                contentMode: .fit,
            )
            .frame(
                maxWidth: .infinity,
            )
    }
}
