@testable import DoglyadSpeech
import Foundation
import Testing

struct DictationSessionTests {
    @Test("A late result from a cancelled session cannot enter a new session")
    func rejectsLateResultAfterCancelAndRestart() throws {
        var gate = DictationSessionGate()
        let started = gate.start()
        let oldID = try #require(started)
        #expect(gate.acceptsResult(for: oldID))

        gate.cancel()
        let restarted = gate.start()
        let newID = try #require(restarted)
        #expect(oldID != newID)
        #expect(!gate.acceptsResult(for: oldID))
        #expect(gate.acceptsResult(for: newID))
        let staleFinalization = gate.beginFinalization(for: oldID)
        #expect(!staleFinalization)
    }

    @Test("A recording cannot restart before finalization finishes")
    func keepsOneSessionDuringFinalization() throws {
        var gate = DictationSessionGate()
        let started = gate.start()
        let id = try #require(started)

        let beganFinalization = gate.beginFinalization(for: id)
        let duplicateFinalization = gate.beginFinalization(for: id)
        let overlappingSession = gate.start()
        #expect(beganFinalization)
        #expect(!duplicateFinalization)
        #expect(overlappingSession == nil)
        #expect(gate.acceptsResult(for: id))

        let finished = gate.finish(for: id)
        #expect(finished)
        #expect(!gate.acceptsResult(for: id))
        let nextSession = gate.start()
        #expect(nextSession != nil)
    }

    @Test("Cancellation while finalizing invalidates the pending result")
    func cancellationBeatsFinalization() throws {
        var gate = DictationSessionGate()
        let started = gate.start()
        let id = try #require(started)
        let beganFinalization = gate.beginFinalization(for: id)
        #expect(beganFinalization)

        gate.cancel()
        let staleFinish = gate.finish(for: id)
        #expect(!staleFinish)
        #expect(!gate.acceptsResult(for: id))
    }

    @Test("Only finished nonempty dictation can be parsed")
    func guardsParsingAfterTimeoutOrInterruption() {
        let incomplete: [DictationCompletion] = [.timedOut, .interrupted, .cancelled, .failed]
        for completion in incomplete {
            let transcript = DictationTranscript(
                rawText: "правая почка 12 мм",
                correctedText: "правая почка 12 мм",
                locale: Locale(identifier: "ru_RU"),
                engine: .sfSpeechRecognizer,
                completion: completion
            )
            #expect(!transcript.isFinal)
            #expect(!transcript.isReadyForParsing)
        }

        let finished = DictationTranscript(
            rawText: "правая почка 12 мм",
            correctedText: "правая почка 12 мм",
            locale: Locale(identifier: "ru_RU"),
            engine: .speechAnalyzer,
            completion: .finished
        )
        #expect(finished.isReadyForParsing)
    }
}
