import UIKit

enum SimulatorCameraImageFactory {
    private static let imageSize = CGSize(
        width: 1024,
        height: 768
    )

    static func makeImage(
        captureNumber: Int
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        return UIGraphicsImageRenderer(
            size: imageSize,
            format: format
        ).image { context in
            let cgContext = context.cgContext
            drawBackground(in: cgContext)
            drawUltrasoundField(
                in: cgContext,
                captureNumber: captureNumber
            )
            drawLabels(
                captureNumber: captureNumber
            )
        }
    }
}

private extension SimulatorCameraImageFactory {
    static func drawBackground(
        in context: CGContext
    ) {
        context.setFillColor(UIColor.black.cgColor)
        context.fill(
            CGRect(
                origin: .zero,
                size: imageSize
            )
        )

        context.setStrokeColor(UIColor(white: 0.35, alpha: 1).cgColor)
        context.setLineWidth(2)
        context.stroke(
            CGRect(
                x: 48,
                y: 56,
                width: imageSize.width - 96,
                height: imageSize.height - 112
            )
        )
    }

    static func drawUltrasoundField(
        in context: CGContext,
        captureNumber: Int
    ) {
        let field = CGMutablePath()
        field.move(
            to: CGPoint(
                x: imageSize.width / 2,
                y: 92
            )
        )
        field.addCurve(
            to: CGPoint(x: 918, y: 682),
            control1: CGPoint(x: 660, y: 210),
            control2: CGPoint(x: 850, y: 480)
        )
        field.addCurve(
            to: CGPoint(x: 106, y: 682),
            control1: CGPoint(x: 690, y: 724),
            control2: CGPoint(x: 334, y: 724)
        )
        field.addCurve(
            to: CGPoint(
                x: imageSize.width / 2,
                y: 92
            ),
            control1: CGPoint(x: 174, y: 480),
            control2: CGPoint(x: 364, y: 210)
        )
        field.closeSubpath()

        context.saveGState()
        context.addPath(field)
        context.clip()

        let colors = [
            UIColor(white: 0.06, alpha: 1).cgColor,
            UIColor(white: 0.35, alpha: 1).cgColor,
            UIColor(white: 0.1, alpha: 1).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0, 0.55, 1]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        )
        if let gradient {
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: imageSize.width / 2, y: 120),
                startRadius: 12,
                endCenter: CGPoint(x: imageSize.width / 2, y: 620),
                endRadius: 520,
                options: [.drawsAfterEndLocation]
            )
        } else {
            context.setFillColor(UIColor(white: 0.15, alpha: 1).cgColor)
            context.fill(
                CGRect(
                    origin: .zero,
                    size: imageSize
                )
            )
        }

        drawSpeckle(
            in: context,
            captureNumber: captureNumber
        )
        drawStructures(
            in: context,
            captureNumber: captureNumber
        )
        context.restoreGState()

        context.addPath(field)
        context.setStrokeColor(UIColor(white: 0.72, alpha: 0.75).cgColor)
        context.setLineWidth(3)
        context.strokePath()
    }

    static func drawSpeckle(
        in context: CGContext,
        captureNumber: Int
    ) {
        var generator = SeededGenerator(
            seed: UInt64(max(captureNumber, 0) + 1)
        )

        for _ in 0 ..< 1400 {
            let x = CGFloat.random(
                in: 90 ... 934,
                using: &generator
            )
            let y = CGFloat.random(
                in: 100 ... 690,
                using: &generator
            )
            let radius = CGFloat.random(
                in: 0.5 ... 2.2,
                using: &generator
            )
            let brightness = CGFloat.random(
                in: 0.35 ... 0.95,
                using: &generator
            )
            let alpha = CGFloat.random(
                in: 0.08 ... 0.42,
                using: &generator
            )

            context.setFillColor(
                UIColor(
                    white: brightness,
                    alpha: alpha
                ).cgColor
            )
            context.fillEllipse(
                in: CGRect(
                    x: x,
                    y: y,
                    width: radius,
                    height: radius
                )
            )
        }
    }

    static func drawStructures(
        in context: CGContext,
        captureNumber: Int
    ) {
        let offset = CGFloat(captureNumber % 7) * 4
        let structures = [
            CGRect(x: 280 + offset, y: 350, width: 450, height: 115),
            CGRect(x: 360 - offset, y: 475, width: 300, height: 82),
            CGRect(x: 430 + offset, y: 575, width: 165, height: 48),
        ]

        for (index, rect) in structures.enumerated() {
            context.setFillColor(
                UIColor(
                    white: index == 1 ? 0.08 : 0.54,
                    alpha: index == 1 ? 0.8 : 0.2
                ).cgColor
            )
            context.fillEllipse(in: rect)
            context.setStrokeColor(
                UIColor(
                    white: 0.85,
                    alpha: 0.2
                ).cgColor
            )
            context.setLineWidth(4)
            context.strokeEllipse(in: rect)
        }
    }

    static func drawLabels(
        captureNumber: Int
    ) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(
                ofSize: 22,
                weight: .semibold
            ),
            .foregroundColor: UIColor.white,
        ]
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(
                ofSize: 17,
                weight: .regular
            ),
            .foregroundColor: UIColor(white: 0.82, alpha: 1),
        ]

        NSString(string: "SIMULATOR MOCK - NOT FOR DIAGNOSIS").draw(
            at: CGPoint(x: 72, y: 72),
            withAttributes: titleAttributes
        )
        NSString(
            format: "DOG-LYAD TEST CAPTURE %02d",
            max(captureNumber, 0)
        ).draw(
            at: CGPoint(x: 72, y: 112),
            withAttributes: detailAttributes
        )
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(
        seed: UInt64
    ) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
