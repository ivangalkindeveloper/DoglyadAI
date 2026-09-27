import DoglyadSpeech
import Testing

/// The corrector substitutes words in a medical report, so its safety properties are
/// pinned down by tests: it must repair homophones and must refuse to substitute
/// anywhere the substitution could invert the meaning.
struct DSpeechLexiconCorrectorTests {
    /// Regression examples of dangerous pairs: opposites differing by a prefix
    /// or a couple of letters. The current per-type hints also include single words.
    private static let terms = [
        "анэхогенное образование",
        "гиперэхогенное образование",
        "гипоэхогенное образование",
        "изоэхогенное образование",
        "дистальное усиление сигнала",
        "капсула не изменена",
        "капсула прослеживается",
        "кальцинаты визуализируются",
        "кальцинаты не определяются",
        "контуры ровные",
        "контуры неровные",
        "контуры четкие",
        "контуры нечеткие",
        "содержимое однородное",
        "содержимое неоднородное",
        "структура однородная",
        "структура неоднородная",
        "эхогенность повышена",
        "эхогенность снижена",
        "васкуляризация усилена",
        "васкуляризация снижена",
        "асцит не определяется",
    ]

    private let corrector = DSpeechLexiconCorrector(terms: terms)

    @Test("Type-specific medical phrases repair spelling without touching measurements")
    func correctsTypeSpecificTerms() {
        let kidney = DSpeechLexiconCorrector(terms: ["почечная лоханка"])
        let heart = DSpeechLexiconCorrector(terms: ["митральный клапан"])

        #expect(kidney.correct("почечная лаханка 12 мм") == "почечная лоханка 12 мм")
        #expect(heart.correct("митральный клопан не изменен") == "митральный клапан не изменен")
    }

    // MARK: - Repairs what it was built for

    @Test("A phonetic vowel variant resolves to the canonical term")
    func correctsPhoneticVariant() {
        #expect(
            corrector.correct("анехогенное образование в правой доле")
                == "анэхогенное образование в правой доле"
        )
    }

    @Test("A missing syllable in the middle of a phrase is restored")
    func correctsMissingSyllable() {
        #expect(
            corrector.correct("дистальное усилие сигнала определяется")
                == "дистальное усиление сигнала определяется"
        )
    }

    @Test("A longer term wins over a nested shorter term")
    func prefersLongerTerm() {
        #expect(
            corrector.correct("дистальное усиление сигнала")
                == "дистальное усиление сигнала"
        )
    }

    // MARK: - Refuses where a substitution changes the meaning

    @Test("Negation is not added to a phrase")
    func neverAddsNegation() {
        #expect(corrector.correct("капсула изменена") == "капсула изменена")
    }

    @Test("Existing negation is not removed")
    func neverRemovesNegation() {
        #expect(corrector.correct("капсула не изменена") == "капсула не изменена")
    }

    @Test(
        "Prefixed opposites are not substituted for one another",
        arguments: [
            "содержимое однородное",
            "содержимое неоднородное",
            "структура однородная",
            "структура неоднородная",
            "контуры ровные",
            "контуры неровные",
            "контуры четкие",
            "контуры нечеткие",
        ]
    )
    func keepsPrefixedOpposites(term: String) {
        #expect(corrector.correct(term) == term)
    }

    @Test(
        "Other semantic opposites are not substituted for one another",
        arguments: [
            "эхогенность повышена",
            "эхогенность снижена",
            "васкуляризация усилена",
            "васкуляризация снижена",
        ]
    )
    func keepsOpposites(term: String) {
        #expect(corrector.correct(term) == term)
    }

    @Test("Similar lesion types are not substituted for one another")
    func keepsEchogenicityFamily() {
        for term in [
            "анэхогенное образование",
            "гиперэхогенное образование",
            "гипоэхогенное образование",
            "изоэхогенное образование",
        ] {
            #expect(corrector.correct(term) == term)
        }
    }

    @Test("Phrases containing numbers remain unchanged")
    func keepsPhrasesWithNumbers() {
        let text = "использован датчик 7,5 мегагерц линейный"
        #expect(corrector.correct(text) == text)
    }

    // MARK: - Does not damage ordinary speech

    @Test(
        "Speech outside the lexicon remains unchanged",
        arguments: [
            "жалобы на боли в правом подреберье",
            "печень увеличена в размерах",
            "пациент иван мужчина рост метр семьдесят четыре",
            "сохранено двенадцать снимков и три видео",
        ]
    )
    func keepsUnrelatedSpeech(text: String) {
        #expect(corrector.correct(text) == text)
    }

    @Test("An empty lexicon makes the corrector an identity function")
    func emptyLexiconIsIdentity() {
        let empty = DSpeechLexiconCorrector(terms: [])
        #expect(empty.correct("анехогенное образование") == "анехогенное образование")
    }

    @Test("Empty text is handled safely")
    func handlesEmptyText() {
        #expect(corrector.correct("") == "")
    }

    @Test("Leading capitalization is preserved during substitution")
    func preservesLeadingCase() {
        #expect(
            corrector.correct("Анехогенное образование в левой доле")
                == "Анэхогенное образование в левой доле"
        )
    }

    // MARK: - General safety property

    /// The key property: a single corruption of a term by a recognition error leads
    /// either to restoring the original term or to leaving the text as is — but never
    /// to turning one dictionary term into another.
    @Test("Corrupting a term never turns it into another dictionary term")
    func neverFlipsOneTermIntoAnother() {
        let vocabulary = Set(Self.terms)

        for term in Self.terms {
            for corrupted in Self.corruptions(of: term) {
                let result = corrector.correct(corrupted)
                guard result != term else { continue }

                #expect(
                    !vocabulary.contains(result),
                    "\(corrupted) became \(result) instead of \(term)"
                )
            }
        }
    }

    /// Corruptions imitating a recognition error: a dropped letter, a swap of adjacent
    /// letters, and a vowel substitution.
    private static func corruptions(
        of term: String
    ) -> [String] {
        var results: [String] = []

        for word in term.split(separator: " ") where word.count > 4 {
            let characters = Array(word)
            for index in 1 ..< (characters.count - 1) {
                var dropped = characters
                dropped.remove(at: index)
                results.append(term.replacingOccurrences(of: String(word), with: String(dropped)))

                var swapped = characters
                swapped.swapAt(index, index + 1)
                results.append(term.replacingOccurrences(of: String(word), with: String(swapped)))

                var replaced = characters
                replaced[index] = "о"
                results.append(term.replacingOccurrences(of: String(word), with: String(replaced)))
            }
        }

        return results
    }
}
