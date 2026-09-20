import DoglyadUI
import SwiftUI

struct ScanCameraFrameView: DView {
    @EnvironmentObject var theme: DTheme
    let onFrameChanged: (CGRect) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * 2 / 3
            let frameColor = color.grayscaleBackgroundWeak
            let cornerLength = size.s48
            let lineWidth = size.s8 / 2
            let cornerRadius = size.s48

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: CGFloat.zero, y: cornerLength))
                    path.addLine(to: CGPoint(x: CGFloat.zero, y: cornerRadius))
                    path.addQuadCurve(
                        to: CGPoint(x: cornerRadius, y: CGFloat.zero),
                        control: CGPoint(x: CGFloat.zero, y: CGFloat.zero)
                    )
                    path.addLine(to: CGPoint(x: cornerLength, y: CGFloat.zero))
                }
                .stroke(frameColor, lineWidth: lineWidth)

                Path { path in
                    path.move(to: CGPoint(x: width - cornerLength, y: CGFloat.zero))
                    path.addLine(to: CGPoint(x: width - cornerRadius, y: CGFloat.zero))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: cornerRadius),
                        control: CGPoint(x: width, y: CGFloat.zero)
                    )
                    path.addLine(to: CGPoint(x: width, y: cornerLength))
                }
                .stroke(frameColor, lineWidth: lineWidth)

                Path { path in
                    path.move(to: CGPoint(x: CGFloat.zero, y: height - cornerLength))
                    path.addLine(to: CGPoint(x: CGFloat.zero, y: height - cornerRadius))
                    path.addQuadCurve(
                        to: CGPoint(x: cornerRadius, y: height),
                        control: CGPoint(x: CGFloat.zero, y: height)
                    )
                    path.addLine(to: CGPoint(x: cornerLength, y: height))
                }
                .stroke(frameColor, lineWidth: lineWidth)

                Path { path in
                    path.move(to: CGPoint(x: width - cornerLength, y: height))
                    path.addLine(to: CGPoint(x: width - cornerRadius, y: height))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: height - cornerRadius),
                        control: CGPoint(x: width, y: height)
                    )
                    path.addLine(to: CGPoint(x: width, y: height - cornerLength))
                }
                .stroke(frameColor, lineWidth: lineWidth)
            }
            .frame(
                width: width,
                height: height
            )
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                onFrameChanged(frame)
            }
        }
        .aspectRatio(
            3.0 / 2.0,
            contentMode: .fit
        )
        .frame(maxWidth: .infinity)
    }
}
