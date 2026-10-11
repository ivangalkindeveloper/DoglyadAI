import Combine
@testable import Doglyad
import Router
import Testing
import UIKit

@MainActor
struct ModuleStateTests {
    @Test
    func subscriptionChangesReachModulesAndObservationIsReleased() throws {
        let container = DependencyContainer.previewable
        let root = SubscriptionRootViewModel(
            container: container,
        )
        root.update(
            status: nil,
        )
        var requestCountUpdates = 0
        var observationCancelled = false
        var model: DModuleViewModel? = DModuleViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { root.status },
            observeSubscriptionStatus: { observer in
                let observation = root.observeStatus(
                    observer,
                )
                return AnyCancellable {
                    observationCancelled = true
                    observation.cancel()
                }
            },
            onSubscriptionStatusUpdated: { root.update(
                status: $0,
            ) },
            getNeuralModelSettings: { root.neuralModelSettings },
            onRequestCountIncremented: { requestCountUpdates += 1 },
            analyticsDestination: .screen(
                .scan,
            ),
        )
        weak var weakModel = model
        #expect(
            model?.isSubscriptionActive == false,
        )
        #expect(
            model?.isNeuralModelSettingsVisible == false,
        )

        let status = SubscriptionStatus(
            type: .pro,
            entitlement: SubscriptionEntitlement(
                requestCountPerDay: 20,
                formCompletionViaMicrophone: .available,
                sendingReportByEmail: .available,
                neuralModelSettings: .available,
            ),
            availableCountPerDay: 17,
        )
        root.update(
            status: status,
        )
        #expect(
            model?.isSubscriptionActive == true,
        )
        #expect(
            model?.availableRequestCount == 17,
        )
        #expect(
            model?.isNeuralModelSettingsVisible == true,
        )
        #expect(
            model?.subscriptionAvailability(
                of: .sendingReportByEmail,
            ) == .available,
        )

        model?.incrementRequestCount()
        #expect(
            requestCountUpdates == 1,
        )
        model?.updateSubscriptionStatus(
            nil,
        )
        #expect(
            root.status == nil,
        )
        #expect(
            model?.isNeuralModelSettingsVisible == false,
        )
        model = nil
        #expect(
            weakModel == nil,
        )
        #expect(
            observationCancelled,
        )
    }

    @Test
    func photoViewerTracksSourceChangesAndDeletesThroughArguments() {
        let container = DependencyContainer.previewable
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let first = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let second = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let third = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let source = CurrentValueSubject<[USExaminationScanPhoto], Never>(
            [first, second],
        )
        let arguments = PhotoViewArguments(
            getPhotos: { source.value },
            observePhotos: { source.sink(
                receiveValue: $0,
            ) },
            initialPhotoID: first.id,
            onDelete: { photo in source.send(
                source.value.filter { $0.id != photo.id },
            ) },
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .photoView,
                arguments: arguments,
            ),
        )
        let model = PhotoViewViewModel(
            container: container,
            router: router,
            getSubscriptionStatus: { root.status },
            observeSubscriptionStatus: { root.observeStatus(
                $0,
            ) },
            onSubscriptionStatusUpdated: { root.update(
                status: $0,
            ) },
            getNeuralModelSettings: { root.neuralModelSettings },
            onRequestCountIncremented: {},
            arguments: arguments,
        )
        model.onTapDelete()
        #expect(
            source.value.map(
                \.id,
            ) == [second.id],
        )
        #expect(
            model.photos.map(
                \.id,
            ) == [second.id],
        )
        #expect(
            model.selectedPhotoID == second.id,
        )
        source.send(
            [second, third],
        )
        #expect(
            model.photos.map(
                \.id,
            ) == [second.id, third.id],
        )
        #expect(
            model.currentPage == 1,
        )
        source.send(
            [],
        )
        #expect(
            !model.isPhotoAvailable,
        )
        #expect(
            router.path.isEmpty,
        )
    }
}
