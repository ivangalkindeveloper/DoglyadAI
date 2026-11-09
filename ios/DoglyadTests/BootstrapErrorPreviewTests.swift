@testable import Doglyad
import Foundation
import Testing

@MainActor
struct BootstrapErrorPreviewTests {
    @Test
    func bootstrapErrorsSelectTheirRealPresentationWithoutInitializedServices() {
        #expect(
            ErrorRootViewModel(
                error: InitializationError.noInternetConnection,
                analytics: nil,
            ).state is ErrorRootOfflineErrorState,
        )
        let unavailable = ErrorRootViewModel(
            error: InitializationError.serviceUnavailable(
                email: "support@doglyad.ru",
            ),
            analytics: nil,
        )
        #expect(
            (unavailable.state as? ErrorRootServiceUnavailableErrorState)?.email == "support@doglyad.ru",
        )
        #expect(
            ErrorRootViewModel(
                error: InitializationError.usExaminationTypesEmpty,
                analytics: nil,
            ).state is ErrorRootUnknownErrorState,
        )
        var retries = 0
        unavailable.onTapRetry {
            retries += 1
        }
        #expect(
            retries == 1,
        )
    }
}
