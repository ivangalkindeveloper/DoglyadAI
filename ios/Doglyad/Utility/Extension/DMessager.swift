import DoglyadUI

extension DMessager {
    func showUnknownError(
        l10n: L10N,
    ) {
        show(
            type: .error,
            title: l10n[
                .errorUnknownTitle,
            ],
            description: l10n[
                .errorUnknownDescription,
            ],
        )
    }
}
