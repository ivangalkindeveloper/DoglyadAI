#if DEBUG
    import Combine
    import DoglyadSpeech
    import DoglyadUI
    import Foundation

    @MainActor
    struct ScanSpeechTranscriptPreviewFixture {
        enum Scenario: Hashable {
            case finished
            case interrupted
            case failed
            case parsing
        }

        let text: String
        let completion: DSpeechCompletion
        let state: any ScanSpeechStateProtocol

        init(
            scenario: Scenario,
        ) {
            text = switch scenario {
            case .finished, .parsing:
                "Номер исследования: 00123. Пациент: Иванов Иван Иванович. Пол: мужской. Дата рождения: 15 марта 1978 года. Рост: 175 сантиметров. Вес: 82 килограмма. Жалобы: периодическая боль в правом подреберье. Описание исследования: печень не увеличена, контуры ровные, структура однородная."
            case .interrupted:
                """
                Номер исследования: 00124. Пациент: Петрова Анна Сергеевна. Пол: женский. Дата рождения: 23 октября 1985 года. Рост: 168 сантиметров. Вес: 64 килограмма.

                Жалобы: дискомфорт в поясничной области справа в течение трёх дней, повышение температуры отрицает.

                Описание исследования: правая почка расположена обычно, размеры 110 на 48 миллиметров. Контуры ровные, чёткие. Толщина паренхимы 16 миллиметров. Чашечно-лоханочная система не расширена. В нижней чашечке определяется гиперэхогенное включение до 4 миллиметров с акустической тенью.

                Левая почка расположена обычно, размеры 108 на 46 миллиметров. Контуры ровные, чёткие. Толщина паренхимы 17 миллиметров. Чашечно-лоханочная система не расширена, конкременты не определяются.

                Мочевой пузырь умеренно наполнен, стенка не утолщена, содержимое однородное. Остаточный объём мочи
                """
            case .failed:
                ""
            }
            completion = switch scenario {
            case .finished, .parsing: .finished
            case .interrupted: .interrupted
            case .failed: .failed
            }
            state = switch scenario {
            case .finished, .interrupted, .failed:
                ScanSpeechReviewTranscriptState()
            case .parsing:
                ScanSpeechReviewParsingState(
                    parsedText: text,
                )
            }
        }

        func makeViewModel(
            container: DependencyContainer,
            messager: DMessager,
            router: DRouter,
        ) -> ScanSpeechViewModel {
            let speechController = ScanSpeechTranscriptPreviewController(
                locale: container.language.currentLocale,
                contextualStrings: [],
                lexiconLocalization: container.l10n.voice.speech,
            )
            // An empty recognition result initializes review without starting parsing.
            // Fill the editable text afterwards, keeping Canvas offline and deterministic.
            speechController.lastTranscript = DSpeechTranscript(
                rawText: "",
                correctedText: "",
                locale: container.language.currentLocale,
                engine: .whisperKit,
                completion: completion,
            )
            let model = ScanSpeechPreviewFactory.makeViewModel(
                container: container,
                messager: messager,
                router: router,
                speechController: speechController,
            )
            model.onInit()
            model.transcriptTextController.setText(
                text,
            )
            model.emit(
                state,
                animation: nil,
            )
            return model
        }
    }

    @MainActor
    private final class ScanSpeechTranscriptPreviewController: DSpeechControllerProtocol {
        let recordingStatus: DSpeechRecordingStatus = .stopped
        let text: String? = nil
        let audioMeter: Float = 0
        @Published var lastTranscript: DSpeechTranscript?

        init(
            locale _: Locale,
            contextualStrings _: [String],
            lexiconLocalization _: DSpeechLexiconLocalization,
        ) {}

        func start() {}

        func stop() async -> DSpeechTranscript? {
            lastTranscript
        }

        func cancel() -> DSpeechTranscript? {
            nil
        }
    }
#endif
