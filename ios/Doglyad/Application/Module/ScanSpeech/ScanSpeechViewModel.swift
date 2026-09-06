import Combine
import DoglyadNeuralModel
import DoglyadSpeech
import DoglyadUI
import SwiftUI

@MainActor
final class ScanSpeechViewModel: DViewModel {
    private let messager: DMessager
    private let arguments: ScanSpeechBottomSheetArguments
    private(set) var speechController: any DSpeechControllerProtocol
    private var speechCancellable: AnyCancellable?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: ScanSpeechBottomSheetArguments
    ) {
        self.messager = messager
        self.arguments = arguments
        let contextualStrings = container.getContextualStrings(for: Locale.current)
        speechController = DSpeechFactory.makeDefault(
            locale: Locale.current,
            contextualStrings: contextualStrings
        )
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
        observeSpeechController()

        Task { [weak self] in
            let controller = await DSpeechFactory.make(
                locale: Locale.current,
                contextualStrings: contextualStrings
            )
            guard let self else { return }
            guard self.speechController.status == .stopped,
                  type(of: controller) != type(of: self.speechController) else { return }

            self.objectWillChange.send()
            self.speechController = controller
            self.observeSpeechController()
        }
    }

    private func observeSpeechController() {
        speechCancellable = speechController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    @Published var isLoading = false
    let columns = [GridItem(.adaptive(minimum: 100))]

    func onTapBack() {
        coordinator.dismissSheet()
    }

    var speechIcon: ImageResource {
        switch speechController.status {
        case .preparing,
             .recording:
            return .check
        case .stopped:
            return .play
        @unknown default:
            fatalError()
        }
    }

    var isSpeechButtonLoading: Bool {
        guard !isLoading else { return true }

        switch speechController.status {
        case .preparing:
            return true
        case .recording,
             .stopped:
            return false
        @unknown default:
            fatalError()
        }
    }

    var isAudioMeterVisible: Bool {
        switch speechController.status {
        case .recording:
            return true
        case .preparing,
             .stopped:
            return false
        @unknown default:
            fatalError()
        }
    }

    var isPreparingDescriptionVisible: Bool {
        switch speechController.status {
        case .preparing:
            return true
        case .recording,
             .stopped:
            return false
        @unknown default:
            fatalError()
        }
    }

    var speechText: String? {
        isAudioMeterVisible ? speechController.text : nil
    }

    var isSpeechTextVisible: Bool {
        speechText != nil
    }

    var audioMeterLevel: Float {
        speechController.audioMeter
    }

    func onTapSpeech() {
        guard !isLoading else { return }

        switch speechController.status {
        case .preparing:
            return
        case .recording:
            onStopSpeech()
        case .stopped:
            speechController.start()
            container.examinationNeuralModelFactory?.prewarm()
        @unknown default:
            fatalError()
        }
    }

    private func onStopSpeech() {
        isLoading = true

        Task { [weak self] in
            guard let self else { return }

            let speech = await self.speechController.stop()
            guard let speech, !speech.isEmpty,
                  self.container.examinationNeuralModelFactory != nil
            else {
                self.isLoading = false
                return
            }

            self.onParseSpeech(speech: speech)
        }
    }

    private func onParseSpeech(
        speech: String
    ) {
        guard let factory = container.examinationNeuralModelFactory else { return }

        handle {
            try await factory.model().parseSpeech(
                speech: speech
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { response in
            self.arguments.onComplete?(response)
            self.coordinator.dismissSheet()
        } onUnknownError: { _ in
            self.messager.showUnknownError()
        }
    }
}
