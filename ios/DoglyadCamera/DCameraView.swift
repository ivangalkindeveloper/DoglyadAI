import SwiftUI

public struct DCameraView<Controller: DCameraController>: UIViewRepresentable {
    private let controller: Controller

    public init(
        controller: Controller
    ) {
        self.controller = controller
    }

    public func makeUIView(context _: Context) -> UIView {
        controller.makePreviewView()
    }

    public func updateUIView(
        _ view: UIView,
        context _: Context
    ) {
        controller.updatePreviewView(view)
    }
}
