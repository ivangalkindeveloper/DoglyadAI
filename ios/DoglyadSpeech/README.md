# DoglyadSpeech

Модуль отвечает за **запись и распознавание речи**. Его результат — текст с происхождением и признаками качества, а не заполненная форма. Извлечение полей находится в [DoglyadNeuralModel](../DoglyadNeuralModel/README.md), сохранение формы — в модуле `Scan`.

Все собственные типы модуля, включая вложенные вспомогательные типы, имеют префикс `DSpeech`.

## Структура папок

| Папка | Содержимое |
|---|---|
| `SpeechAnalyzer/` | Контроллер SpeechAnalyzer, конфигурация DictationTranscriber, распознавание файла и преобразователь PCM-буферов. |
| `SFSpeechRecognizer/` | Контроллер SFSpeechRecognizer, распознавание файла и передача аудиобуферов с сохранением хвоста между задачами. |
| `WhisperKit/` | Контроллер WhisperKit, подготовка модели и расшифровка с повторной проверкой сегментов. |
| `Span/` | `DSpeechConfidenceSpan` — confidence Apple Speech; `DSpeechDecodingSpan` — оценки Whisper и повторная расшифровка. Оба типа привязывают данные к UTF-16-диапазону исходного текста. |
| `Audio/` | Общая аудиосессия, измеритель уровня звука и словарная коррекция с её языковыми данными. |
| `Controller/` | Общий протокол контроллеров, защита сессии, результат и ошибки файлового Apple-распознавания. |
| Корень модуля | Фабрика, общие состояния, транскрипт, тип движка, завершение записи и общая ошибка. |

В папку движка попадают файлы, относящиеся только к нему. Общие типы не дублируются между реализациями.

## Текущий рабочий путь

`DSpeechFactory` всегда создаёт `DSpeechControllerWhisperKit`. SpeechAnalyzer и SFSpeechRecognizer сохранены для сравнений, автоматически вместо Whisper не выбираются.

Контроллер публикует два отдельных статуса: `modelPreparationStatus: DSpeechModelPreparationStatus` описывает подготовку модели, а `recordingStatus: DSpeechRecordingStatus` — запись и распознавание речи. Подготовка запускается через `prepareModel()`.

```mermaid
flowchart TD
    Input["ScanSpeechViewModel<br/>locale = ru<br/>contextualStrings = «щитовидная железа», …"] --> Factory[DSpeechFactory]
    Factory --> Controller[DSpeechControllerWhisperKit]
    Controller --> Model[DSpeechWhisperKitModel: общий кэш]
    Model --> Prepare[DSpeechModelPreparationStatus]
    Prepare -->|"checking → downloading: 0.42 → loading → ready"| UI[ScanSpeechViewModel]
    Model -->|файлов нет| Download[Скачивание Turbo + прогресс]
    Download --> Load[Загрузка Core ML и токенизатора]
    Model -->|файлы есть| Load
    Load --> Ready[ready: кнопка записи доступна]
    Ready --> Controller
    Controller --> Session["DSpeechSessionGate<br/>UUID текущей записи"]
    Controller --> Audio[DSpeechWhisperKitAudioProcessor → AVAudioEngine]
    Audio --> Samples["Буферы Float32<br/>16 кГц, mono"]
    Audio -->|audioMeter| UI
    Samples --> Stream[AudioStreamTranscriber]
    Stream -->|"подтверждённые + черновые фразы → text"| UI
    Samples -->|"после stop и завершения потока"| Recognition[DSpeechWhisperKitTranscription]
    Model --> Recognition
    Recognition --> First["WhisperKit: TranscriptionResult<br/>text + segments: время, текст, оценки"]
    First --> Raw["rawText<br/>Рост: 178 см. Вес: 82 кг.<br/>Описание исследования: Щитовидная жилеза без узлов."]
    First --> Repeat["Повтор аудиосегмента<br/>0…2.4 с → повтор 0…2.75 с"]
    Repeat --> Spans[DSpeechDecodingSpan]
    Spans -->|"start = 0, length = 25, avgLogProb = −0.10<br/>recheckedText = «Рост: 178 см. Вес: 82 кг.»"| Transcript
    Raw --> Correction[DSpeechLexiconCorrector]
    Vocabulary[Фразы типа исследования + DSpeechLexiconLocalization текущего языка] --> Correction
    Correction --> Corrected["correctedText<br/>жилеза → железа<br/>Числа, отрицания и пунктуация сохранены"]
    Raw --> Transcript["DSpeechTranscript<br/>rawText + correctedText + decodingSpans<br/>confidenceSpans = [], completion = finished"]
    Corrected --> Transcript
    Transcript -->|"text = correctedText; lastTranscript = весь результат"| UI
    UI --> Parsing[Извлечение полей и проверка автозаполнения]
```

1. При открытии шторки проверяется модель `large-v3-v20240930_626MB`. UI показывает проверку, скачивание или загрузку; запись доступна после `ready`.
2. `AudioStreamTranscriber` распознаёт поступающие моно-буферы Float32, 16 кГц. Подтверждённые и черновые сегменты проходят словарную коррекцию и публикуются через `text` во время записи. Служебные сообщения SDK не отображаются.
3. После остановки микрофона потоковая задача завершается; затем вся накопленная запись заново распознаётся локально. Для записей длиннее 30 секунд используется VAD-разбиение. Поток и финальная проверка используют общую модель последовательно, включая отмену и запуск новой шторки.
4. Каждый сегмент повторно распознаётся. Стабильность и оценки декодера передаются приложению; совпадение двух расшифровок само по себе не доказывает медицинскую точность.
5. Словарная коррекция использует фразы выбранного типа исследования. Она сохраняет пунктуацию и пробелы, не меняет числа, отрицания, стороны и окончания слов. Эти ограничения получают словари только текущего языка.
6. `rawText` и `correctedText` хранятся отдельно. `ScanSpeech` решает, можно ли сразу разбирать результат или нужно показать незавершённую запись для проверки.
7. Аудио хранится в памяти до завершения обработки; временные записи на диск не создаются. Отмена останавливает микрофон и обработку, а поздние результаты не применяются. Удаление модели отменяет и дожидается всех обращений к декодеру перед выгрузкой.

**Контекстные фразы сейчас используются для коррекции текста. В `promptTokens` декодера Whisper они не передаются.** Прежний эксперимент с прямой подсказкой ухудшал итоговую точность форм.

## Сквозной пример данных

Ниже один учебный пример для УЗИ щитовидной железы. Тексты показывают движение данных; длительность и оценки декодера условные и не являются результатом замера. Исправление `жилеза → железа` проверено на текущем `DSpeechLexiconCorrector` с RU-каталогом.

### 1. Подготовка и запись

| Откуда → куда | Вход | Что происходит / выход |
|---|---|---|
| Приложение → `DSpeechFactory` → `DSpeechControllerWhisperKit` | `locale = Locale(identifier: "ru")`; фразы исследования: `«щитовидная железа»`, `«щитовидная железа без узлов»`; RU-каталог `DSpeechLexiconLocalization` | Контроллер создаёт корректор с этими фразами. Язык распознавания Whisper будет `ru`. |
| `DSpeechWhisperKitModel` → контроллер → UI | Вариант `large-v3-v20240930_626MB`; путь к кэшу модели | Если файлов нет: `.checking → .downloading(progress: nil) → .downloading(progress: 0.42) → .loading → .ready`. `0.42` означает 42% скачивания. При готовом экземпляре сразу `.ready`. |
| `DSpeechAudioSession` → `DSpeechWhisperKitAudioProcessor` | Аудиомаршрут, например `.builtIn` | `AVAudioEngine` передаёт буферы Float32, 16 кГц, mono. Адаптер сохраняет настройки микрофона и Bluetooth приложения и предоставляет потоковому декодеру синхронизированные снимки аудио. |
| `AudioStreamTranscriber` → контроллер → UI | Подтверждённые и черновые сегменты | Контроллер публикует текущую расшифровку в `text`; индикатор получает относительную энергию звука `0…1`. Это не оценка качества распознавания. |
| `stop()` → `DSpeechWhisperKitTranscription` | Полный массив аудиосэмплов, `language = "ru"`, загруженный экземпляр `WhisperKit` | Микрофон останавливается, состояние становится `.transcribing`; потоковая задача завершается до полного ASR-прогона и повторной проверки сегментов. Для длительности более 30 с включается VAD-разбиение. |

### 2. Аудио → исходный текст → диагностика

Whisper возвращает `TranscriptionResult.text` и аудиосегменты `TranscriptionSegment`. `DSpeechWhisperKitTranscription` объединяет тексты результатов пробелом, убирает пробелы по краям и получает:

```text
rawText = Рост: 178 см. Вес: 82 кг. Описание исследования: Щитовидная жилеза без узлов.
```

Пример сегментов одного результата:

| Сегмент | Время в аудио | `segment.text` после удаления служебных токенов | Диапазон в `rawText` |
|---|---|---|---|
| 1 | `0…2.4 с` | `Рост: 178 см. Вес: 82 кг.` | `utf16Start = 0`, `utf16Length = 25` |
| 2 | `2.4…5.8 с` | `Описание исследования: Щитовидная жилеза без узлов.` | `utf16Start = 26`, `utf16Length = 51` |

Границы сегментов определяет Whisper; они не обязаны совпадать с предложениями. Каждый сегмент повторно распознаётся с запасом 0,35 с по краям. Например, для сегмента 1 загружаются Float-аудиосэмплы интервала `0…2.75 с`, затем снова вызывается Whisper. Это повторное распознавание того же звука, а не проверка текста языковой моделью.

В первый `DSpeechDecodingSpan` попадают:

```swift
DSpeechDecodingSpan(
    utf16Start: 0,
    utf16Length: 25,
    averageLogProbability: -0.10,
    temperature: 0,
    compressionRatio: 1.10,
    recheckedText: "Рост: 178 см. Вес: 82 кг.",
)
```

| Свойство | Значение в примере | Смысл |
|---|---|---|
| `utf16Start`, `utf16Length` | `0`, `25` | Положение **в исходном `rawText`**, не секунды аудио. Для символов вне BMP один видимый символ может занимать две UTF-16-единицы. |
| `averageLogProbability` | `−0.10` | Средняя логарифмическая оценка выбранных токенов декодером; не процент точности. |
| `temperature` | `0` | Температура, с которой Whisper получил этот сегмент. |
| `compressionRatio` | `1.10` | Диагностическое отношение сжатия текста: используется для выявления подозрительных повторов. |
| `recheckedText` | `Рост: 178 см. Вес: 82 кг.` | Ответ повторного распознавания аудиофрагмента. Ошибка повторной проверки оставляет пустой ответ; ошибка сопоставления сегмента с текстом не создаёт span. |

### 3. Словарная коррекция → итоговый результат

```text
DSpeechLexiconCorrector получает rawText:
Рост: 178 см. Вес: 82 кг. Описание исследования: Щитовидная жилеза без узлов.

Возвращает correctedText:
Рост: 178 см. Вес: 82 кг. Описание исследования: Щитовидная железа без узлов.
```

Корректор сравнивает похожие по звучанию многословные фразы со словарём выбранного исследования. Здесь изменена только `жилеза`; `178`, `82`, `см`, `кг`, `без узлов` и пунктуация сохраняются. `rawText` не перезаписывается. Диагностика сегментов и повторная расшифровка тоже остаются привязанными к исходному тексту.

| Поле `DSpeechTranscript` | Что передаётся в этом примере |
|---|---|
| `rawText` | Исходная строка с `жилеза`. |
| `correctedText` | Строка с `железа`; если коррекции не было, совпадает с `rawText`. Это не текст после ручной правки врача. |
| `locale`, `engine` | `Locale(identifier: "ru")`, `.whisperKit`. |
| `completion` | `.finished`, если запись и расшифровка завершились штатно. |
| `confidenceSpans` | `[]`: Whisper-контроллер не заполняет оценки Apple Speech. |
| `decodingSpans` | Два `DSpeechDecodingSpan` из таблицы сегментов, с оценками Whisper и повторными текстами. |

Контроллер публикует `text = correctedText`, `lastTranscript = весь DSpeechTranscript` и `.stopped`. `isReadyForParsing` допускает непустой текст любой неотменённой записи; возможность автоматического применения дополнительно проверяет приложение. Далее приложение передаёт строку в [DoglyadNeuralModel](../DoglyadNeuralModel/README.md#сквозной-пример-данных), а весь транскрипт сохраняет для последующей проверки автозаполнения. Изменённый корректором медицинский фрагмент не получает доверие только из-за высоких оценок исходного Whisper.

### 4. Прерывание и отмена

| Ситуация | Результат |
|---|---|
| Аудиозахват или потоковый декодер неожиданно остановился | Контроллер завершает запись с `.interrupted` и выполняет финальный прогон. Приложение учитывает незавершённость записи при проверке надёжности отдельных полей. |
| Запись не стартовала | `.failed`, пустой `rawText`, пустые `decodingSpans`; автоматический разбор не начинается. |
| Финальный Whisper-прогон завершился ошибкой | Сохраняется последняя промежуточная расшифровка с `.failed` и пустыми `decodingSpans`; её можно проверить вручную, оснований для автоматического применения Whisper-полей нет. |
| Проверка отдельного сегмента не удалась | Основной текст сохраняется, `recheckedText` этого сегмента пустой; затронутые поля не получают подтверждения стабильностью сегмента. |
| Пользователь отменил запись A, затем начал B | `DSpeechSessionGate` хранит UUID B; поздний `finish(A)` возвращает `false`. Результат A не становится `lastTranscript` и не заполняет форму. |

Промежуточные результаты не становятся `lastTranscript` и не заполняют форму. Подписка `ScanSpeechViewModel` отдельно передаёт изменения `text` и `audioMeter` в UI; для этого не требуется повторно публиковать неизменившийся lifecycle state.

## Типы и назначение

### Рабочая запись и Whisper

| Тип | Назначение |
|---|---|
| `DSpeechFactory` | Создаёт выбранный рабочий контроллер — WhisperKit. |
| `DSpeechControllerProtocol` | Общий наблюдаемый интерфейс: подготовка, старт, остановка, отмена, состояние и результат. |
| `DSpeechControllerWhisperKit` | Управляет потоком, публикует предпросмотр, останавливает микрофон и собирает проверенный итоговый результат. |
| `DSpeechWhisperKitAudioProcessor` | Адаптер захвата WhisperKit: настройки аудиосессии приложения, синхронизированные буферы и относительная энергия звука. |
| `DSpeechWhisperKitModel` | Один экземпляр Whisper, подготовка и последовательное выполнение задач декодера; проверяет кэш, скачивает файлы, публикует прогресс и безопасно удаляет модель. |
| `DSpeechWhisperKitTranscription` | Полная расшифровка и повтор сегментов; сопоставляет сегменты с UTF-16-позициями текста. |
| `DSpeechSessionGate` | Защищает от двойной финализации и поздних результатов отменённой/старой записи. |
| `DSpeechLexiconCorrector` | Консервативная коррекция похожих медицинских фраз по словарю выбранного исследования. |
| `DSpeechLexiconLocalization` | Отрицания, стороны и символьные соответствия выбранного языка; декодируется из ответа `/v1/l10n` и передаётся аргументом. |

### Состояния и результат

| Тип | Назначение |
|---|---|
| `DSpeechRecordingStatus` | Этап записи: подготовка, запись, распознавание, остановка. |
| `DSpeechModelPreparationStatus` | Проверка модели, скачивание с прогрессом, загрузка, готовность либо ошибка. |
| `DSpeechTranscript` | Исходный/исправленный текст, локаль, движок, причина завершения и признаки качества. `isReadyForParsing` проверяет непустой текст и отсутствие отмены. |
| `DSpeechEngine` | Происхождение текста: WhisperKit, SpeechAnalyzer, SFSpeechRecognizer. |
| `DSpeechCompletion` | Нормальное завершение, таймаут, прерывание, ошибка или отмена. |
| `DSpeechDecodingSpan` | UTF-16-диапазон Whisper, log probability, температура, compression ratio и повторная расшифровка. |
| `DSpeechConfidenceSpan` | UTF-16-диапазон и confidence Apple Speech; используется сохранёнными Apple-реализациями и тестами. |
| `DSpeechError` | Общая недоступность записи/распознавания. |

### Apple-реализации, сохранённые для сравнения

| Тип | Назначение / статус |
|---|---|
| `DSpeechControllerAnalyzer` | Прежняя потоковая запись и распознавание через SpeechAnalyzer/DictationTranscriber на iOS 26. Рабочая фабрика не выбирает. |
| `DSpeechAnalyzerConfiguration` | Общие настройки DictationTranscriber, контекст, установка языковых ресурсов. |
| `DSpeechControllerSFSpeechRecognizer` | Прежняя запись через SFSpeechRecognizer с ожиданием финального результата. Рабочая фабрика не выбирает. |
| `DSpeechFileTranscriber` | Прогон сохранённого аудиофайла через SpeechAnalyzer для сравнения ASR. |
| `DSpeechFileRecognizerSFSpeechRecognizer` | Прогон сохранённого файла через SFSpeechRecognizer для сравнения ASR. |
| `DSpeechFileTranscription` | Текст и confidence из файлового Apple-распознавания. |
| `DSpeechFileTranscriberError` | Диагностика несовместимого формата, недоступного языка, таймаута или сбоя файлового распознавания. |

### Аудиоинфраструктура

| Тип | Назначение / где используется |
|---|---|
| `DSpeechAudioSession` | Настраивает и освобождает AVAudioSession; используется Whisper и Apple-контроллерами. |
| `DSpeechAudioRoute` | Источник аудио (встроенный микрофон или гарнитура); используется при настройке аудиосессии и подсказках. |
| `DSpeechAudioRelay` | Передаёт микрофонные буферы в SFSpeechRecognizer; сохраняет и повторяет хвост аудио при смене задачи распознавания. |
| `DSpeechBufferConverter` | Приводит PCM-буфер к формату, совместимому с анализатором. |
| `DSpeechAudioMeter` | Потокобезопасная оценка уровня PCM-буфера для Apple-контроллеров. Whisper использует относительную энергию буферов своего аудиопроцессора. |

```mermaid
flowchart TD
    Compare[Явный выбор в сравнении / прежняя реализация] --> Analyzer[DSpeechControllerAnalyzer]
    Compare --> SF[DSpeechControllerSFSpeechRecognizer]
    Compare --> AnalyzerFile[DSpeechFileTranscriber]
    Compare --> SFFile[DSpeechFileRecognizerSFSpeechRecognizer]
    Analyzer --> Config[DSpeechAnalyzerConfiguration]
    AnalyzerFile --> Config
    Analyzer --> Convert[DSpeechBufferConverter]
    Analyzer --> Meter[DSpeechAudioMeter]
    SF --> Relay[DSpeechAudioRelay]
    SF --> Meter
    Analyzer --> Attributed["DictationTranscriber<br/>AttributedString + transcriptionConfidence"]
    AnalyzerFile --> Attributed
    SF --> Formatted["SFSpeechRecognizer<br/>bestTranscription.formattedString"]
    SFFile --> Formatted
    Attributed --> Confidence[DSpeechConfidenceSpan]
    Attributed --> Corrector[DSpeechLexiconCorrector]
    Formatted --> Corrector
    Confidence --> Result[DSpeechTranscript / DSpeechFileTranscription]
    Corrector --> Result
```

### Какие данные возвращают сохранённые Apple-реализации

| Реализация | Пример входа и промежуточных данных | Результат |
|---|---|---|
| `DSpeechControllerAnalyzer` | Микрофонные PCM-буферы → `DSpeechBufferConverter` → `AnalyzerInput` → `AttributedString`, например `Рост: 178 см. Вес: 82 кг.` с `transcriptionConfidence = 0.96` на диапазоне | `DSpeechConfidenceSpan(utf16Start: 0, utf16Length: 25, confidence: 0.96)`; `decodingSpans = []`. После общей коррекции собирается `DSpeechTranscript(engine: .speechAnalyzer, …)`. |
| `DSpeechControllerSFSpeechRecognizer` | PCM-буферы → `DSpeechAudioRelay` → `SFSpeechAudioBufferRecognitionRequest` → `bestTranscription.formattedString` | Исходный и исправленный текст в `DSpeechTranscript(engine: .sfSpeechRecognizer, …)`. **Текущая реализация оставляет оба массива spans пустыми**, хотя SDK отдельно предоставляет оценки сегментов. |
| `DSpeechFileTranscriber` / `DSpeechFileRecognizerSFSpeechRecognizer` | URL готового аудиофайла, локаль и фразы исследования | `DSpeechFileTranscription(rawText, correctedText, confidenceSpans)`: файловый SpeechAnalyzer добавляет spans из `AttributedString`, файловый SFSpeechRecognizer сейчас оставляет `confidenceSpans = []`. |

В отличие от `decodingSpans`, `confidenceSpans` содержат только диапазон исходного текста и оценку Apple в пределах `0…1`. `0.96` не означает гарантированные 96% медицинской точности. Рабочая фабрика не выбирает эти Apple-реализации вместо WhisperKit.

Вложенные `DSpeechLexiconCorrector.DSpeechLexiconTerm` и `.DSpeechLexiconSide` хранят подготовленную словарную фразу и её сторону. `DSpeechLexiconCodingKeys` задают технические JSON-имена.

## Почему результат содержит больше одной строки

Строка нужна для извлечения значений. Исходный текст и признаки сегментов нужны, чтобы не считать исправленную или нестабильную расшифровку доказательством для автоматического заполнения. Решение о подтверждении находится в `ScanSpeechConfidencePolicy`, а не в ASR-модуле.

Языковые данные находятся только на основном backend: `config/<environment>/<code>/l10n_voice_parsing.json`. Приложение скачивает `/v1/l10n` в Tier 4 для `Language.currentLocale`; `L10N.voice.speech` передаётся в модуль через аргументы и не ищет одновременно русские и английские слова.
