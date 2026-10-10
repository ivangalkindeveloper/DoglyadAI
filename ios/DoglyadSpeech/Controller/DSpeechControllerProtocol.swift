import Combine
import Foundation

/// A speech-to-text controller.
///
/// An observable object: the scanning screen subscribes to `status`, `text` and
/// `audioMeter` to reflect the progress of dictation. The concrete implementation is
/// chosen by ``DSpeechFactory``.
///
/// Requiring `ObjectWillChangePublisher == ObservableObjectPublisher` lets a consumer
/// subscribe to `objectWillChange` through the `any DSpeechControllerProtocol`
/// existential without knowing the concrete type.
@MainActor
public protocol DSpeechControllerProtocol: ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher
{
    init(
        locale: Locale,
        contextualStrings: [String],
        lexiconLocalization: DSpeechLexiconLocalization,
    )

    var status: DSpeechRecordingStatus { get }
    var text: String? { get }
    var audioMeter: Float { get }
    var lastTranscript: DSpeechTranscript? { get }
    var modelPreparation: DSpeechModelPreparation { get }

    func prepareModel()

    func start()

    /// Stops recording and waits for the final recognition result.
    ///
    /// Returns text and its completion status after the audio tail is processed.
    /// A timed-out or interrupted session can retain text for review, but must not
    /// be interpreted as a finished dictation.
    @discardableResult
    func stop() async -> DSpeechTranscript?

    /// Discards an active session and rejects any results that arrive afterwards.
    @discardableResult
    func cancel() -> DSpeechTranscript?
}

public extension DSpeechControllerProtocol {
    var modelPreparation: DSpeechModelPreparation { .ready }

    func prepareModel() {}
}
