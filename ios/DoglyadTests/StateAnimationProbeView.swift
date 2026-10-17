@testable import Doglyad
import SwiftUI
import UIKit

struct StateAnimationProbeView: UIViewRepresentable {
    @ObservedObject var viewModel: DStateViewModel<Int>
    let onTransaction: (Int, Animation?) -> Void

    func makeUIView(
        context _: Context,
    ) -> UIView {
        UIView()
    }

    func updateUIView(
        _: UIView,
        context: Context,
    ) {
        onTransaction(
            viewModel.state,
            context.transaction.animation,
        )
    }
}
