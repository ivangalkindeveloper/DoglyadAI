@testable import Doglyad
import SwiftUI
import UIKit

struct StateAnimationProbeView: UIViewRepresentable {
    @ObservedObject var viewModel: DStateViewModel<Int>
    let onTransaction: (Int, Animation?) -> Void

    init(
        viewModel: DStateViewModel<Int>,
        onTransaction: @escaping (Int, Animation?) -> Void,
    ) {
        self.viewModel = viewModel
        self.onTransaction = onTransaction
    }

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
