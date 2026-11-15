@testable import DoglyadSpeech
import Foundation

final class TOneTestAudioCapture: DSpeechTOneAudioCaptureProtocol {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    let audio = Data(
        [0, 0, 1, 0],
    )

    init() {}

    func start() throws {
        startCount += 1
    }

    func stop() -> Data {
        stopCount += 1
        return audio
    }
}
