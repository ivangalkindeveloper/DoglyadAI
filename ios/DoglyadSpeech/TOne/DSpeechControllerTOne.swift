import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
public final class DSpeechControllerTOne: DSpeechControllerProtocol {
    private let locale: Locale
    private let transcribe: @MainActor (Data) async throws -> String
    private let makeCapture: (DSpeechAudioMeter, @escaping @Sendable (DSpeechCompletion) -> Void) -> any DSpeechTOneAudioCaptureProtocol
    private var capture: (any DSpeechTOneAudioCaptureProtocol)?
    private var pendingAudio: Data?
    private var sessionID: UUID?
    private var completion: DSpeechCompletion = .finished
    private var transcriptionTask: Task<String, Error>?
    private var interruptionObservations: [AnyCancellable] = []
    @Published public private(set) var recordingStatus: DSpeechRecordingStatus = .stopped
    @Published public private(set) var text: String?
    @Published public private(set) var audioMeter: Float = 0
    @Published public private(set) var lastTranscript: DSpeechTranscript?

    public convenience init(
        locale: Locale,
        transcribe: @escaping @MainActor (Data) async throws -> String,
    ) {
        self.init(
            locale: locale,
            transcribe: transcribe,
            makeCapture: { meter, onEnd in
                DSpeechTOneAudioCapture(
                    meter: meter,
                    onEnd: onEnd,
                )
            },
        )
    }

    init(
        locale: Locale,
        transcribe: @escaping @MainActor (Data) async throws -> String,
        makeCapture: @escaping (DSpeechAudioMeter, @escaping @Sendable (DSpeechCompletion) -> Void) -> any DSpeechTOneAudioCaptureProtocol,
    ) {
        self.locale = locale
        self.transcribe = transcribe
        self.makeCapture = makeCapture
    }

    public var isTranscriptionRetryAvailable: Bool {
        pendingAudio != nil && recordingStatus == .stopped
    }

    public func start() {
        guard recordingStatus == .stopped else {
            return
        }
        _ = cancel()
        let id = UUID()
        sessionID = id
        completion = .finished
        lastTranscript = nil
        text = nil
        recordingStatus = .preparing
        let meter = DSpeechAudioMeter { [weak self] level in
            Task { @MainActor [weak self] in
                guard let self, sessionID == id, recordingStatus == .recording else {
                    return
                }
                audioMeter = level
            }
        }
        let capture = makeCapture(
            meter,
        ) { [weak self] completion in
            Task { @MainActor [weak self] in
                guard let self, sessionID == id, recordingStatus == .recording else {
                    return
                }
                self.completion = completion
                _ = await stop()
            }
        }
        self.capture = capture
        do {
            try capture.start()
            recordingStatus = .recording
            for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, UIApplication.didEnterBackgroundNotification] {
                NotificationCenter.default.publisher(
                    for: name,
                ).sink { [weak self] notification in
                    if name == AVAudioSession.routeChangeNotification {
                        guard let value = notification.userInfo?[
                            AVAudioSessionRouteChangeReasonKey,
                        ] as? UInt,
                            let reason = AVAudioSession.RouteChangeReason(
                                rawValue: value,
                            ),
                            [.newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange].contains(
                                reason,
                            )
                        else {
                            return
                        }
                    }
                    if name == AVAudioSession.interruptionNotification {
                        guard let value = notification.userInfo?[
                            AVAudioSessionInterruptionTypeKey,
                        ] as? UInt,
                            AVAudioSession.InterruptionType(
                                rawValue: value,
                            ) == .began
                        else {
                            return
                        }
                    }
                    Task { @MainActor [weak self] in
                        guard let self, sessionID == id, recordingStatus == .recording else {
                            return
                        }
                        completion = .interrupted
                        _ = await stop()
                    }
                }.store(
                    in: &interruptionObservations,
                )
            }
        } catch {
            _ = capture.stop()
            self.capture = nil
            lastTranscript = result(
                text: "",
                completion: .failed,
            )
            recordingStatus = .stopped
        }
    }

    @discardableResult
    public func stop() async -> DSpeechTranscript? {
        guard let id = sessionID, transcriptionTask == nil, capture != nil || pendingAudio != nil else {
            return lastTranscript
        }
        if let capture {
            pendingAudio = capture.stop()
            self.capture = nil
            interruptionObservations.removeAll()
            audioMeter = 0
        }
        guard let audio = pendingAudio, !audio.isEmpty else {
            pendingAudio = nil
            lastTranscript = result(
                text: "",
                completion: .failed,
            )
            recordingStatus = .stopped
            return lastTranscript
        }
        recordingStatus = .transcribing
        let task = Task {
            try Task.checkCancellation()
            return try await transcribe(
                audio,
            )
        }
        transcriptionTask = task
        defer {
            if sessionID == id {
                transcriptionTask = nil
                recordingStatus = .stopped
            }
        }
        do {
            let rawText = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard !Task.isCancelled, sessionID == id else {
                return nil
            }
            pendingAudio = nil
            let transcript = result(
                text: rawText,
                completion: completion,
            )
            text = transcript.correctedText
            lastTranscript = transcript
        } catch {
            guard !Task.isCancelled, sessionID == id else {
                return nil
            }
            lastTranscript = result(
                text: "",
                completion: .failed,
            )
        }
        return lastTranscript
    }

    @discardableResult
    public func cancel() -> DSpeechTranscript? {
        sessionID = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        _ = capture?.stop()
        capture = nil
        pendingAudio = nil
        interruptionObservations.removeAll()
        audioMeter = 0
        text = nil
        lastTranscript = nil
        recordingStatus = .stopped
        return nil
    }

    private func result(
        text: String,
        completion: DSpeechCompletion,
    ) -> DSpeechTranscript {
        DSpeechTranscript(
            rawText: text,
            correctedText: text,
            locale: locale,
            engine: .tOne,
            completion: completion,
        )
    }
}
