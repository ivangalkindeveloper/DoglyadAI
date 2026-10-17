import SwiftUI

struct DUnexpectedStateView: View {
    let state: Any

    var body: some View {
        EmptyView().onAppear {
            preconditionFailure(
                "Unexpected presentation state: \(type(of: state))",
            )
        }
    }
}
