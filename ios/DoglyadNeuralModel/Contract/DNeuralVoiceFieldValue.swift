import Foundation

@frozen public enum DNeuralVoiceFieldValue: Equatable, Sendable {
    case text(String)
    case gender(DNeuralVoiceGender)
    case date(Date)
    case number(Double)
}
