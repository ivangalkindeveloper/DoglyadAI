import Foundation

protocol DSpeechTOneAudioCaptureProtocol: AnyObject {
    func start() throws

    func stop() -> Data
}
