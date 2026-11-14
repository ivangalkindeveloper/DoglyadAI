import DoglyadNeuralModel
import DoglyadSpeech
import Foundation

struct VoiceLocalization: Decodable, Sendable {
    let code: String
    let dictation: DNeuralUltrasoundDictationLocalization
    let speech: DSpeechLexiconLocalization

    init(
        code: String,
        dictation: DNeuralUltrasoundDictationLocalization,
        speech: DSpeechLexiconLocalization,
    ) {
        self.code = code
        self.dictation = dictation
        self.speech = speech
    }
}
