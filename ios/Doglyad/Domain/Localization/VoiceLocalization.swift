import DoglyadNeuralModel
import DoglyadSpeech
import Foundation

struct VoiceLocalization: Decodable, Sendable {
    let code: String
    let dictation: DNeuralUltrasoundDictationLocalization
    let speech: DSpeechLexiconLocalization
}
