import DoglyadUI

extension DMessager {
    func showUnknownError() {
        show(
            type: .error,
            title: .errorUnknownTitle,
            description: .errorUnknownDescription,
        )
    }
}
