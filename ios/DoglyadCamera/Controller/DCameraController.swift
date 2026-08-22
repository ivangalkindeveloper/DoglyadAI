import Combine
import UIKit

@MainActor
public protocol DCameraController: AnyObject, ObservableObject {
    var isLoading: Bool { get }
    var isRunning: Bool { get }
    var isCapturing: Bool { get }

    func startSession()

    func stopSession()

    func takePhoto(
        completion: @escaping (UIImage) -> Void
    )

    func makePreviewView() -> UIView

    func updatePreviewView(
        _ view: UIView
    )
}
