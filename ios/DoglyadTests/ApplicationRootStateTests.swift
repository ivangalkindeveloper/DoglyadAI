@testable import Doglyad
import Foundation
import Testing

@MainActor
struct ApplicationRootStateTests {
    @Test
    func startingInitializationKeepsSplashIdentity() {
        let initial = ApplicationRootInitialState()
        let initializing = ApplicationRootInitializingState()
        let ready = ApplicationRootReadyState(
            container: .previewable,
        )
        #expect(
            initial.id == .splash,
        )
        #expect(
            initializing.id == initial.id,
        )
        #expect(
            ready.id == .main,
        )
    }

    @Test
    func retryKeepsErrorIdentityAndPreservesFailureData() {
        let failure = ApplicationRootFailedState(
            error: NSError(
                domain: "Initial failure",
                code: 1,
            ),
        )
        let retry = ApplicationRootInitializingState(
            previousFailure: failure,
        )
        let nextFailure = ApplicationRootFailedState(
            error: NSError(
                domain: "Retry failure",
                code: 2,
            ),
        )
        #expect(
            failure.id == .error,
        )
        #expect(
            retry.id == failure.id,
        )
        #expect(
            retry.previousFailure === failure,
        )
        #expect(
            nextFailure.id == failure.id,
        )
        #expect(
            (nextFailure.error as NSError).domain == "Retry failure",
        )
    }
}
