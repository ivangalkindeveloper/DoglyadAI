# Оценка голосового заполнения формы: текст, аудио и iOS

Полное сравнение четырёх клиентских ASR на физическом iPhone и предварительный
отсев Qwen3-ASR: [CLIENT_ASR_COMPARISON.md](CLIENT_ASR_COMPARISON.md).
Сравнение способов извлечения полей из готового пунктуированного текста:
[IDEAL_TEXT_EXTRACTION_COMPARISON.md](IDEAL_TEXT_EXTRACTION_COMPARISON.md).

## Сквозная проверка текущего рабочего пути на iPhone

Отдельная проверка Foundation Models от 10 октября завершена без GPU:
76 EN-случаев, результат самой модели и рабочего пути показаны отдельно:
[FOUNDATION_MODELS_DEVICE_2026_10_10_REPORT.md](FOUNDATION_MODELS_DEVICE_2026_10_10_REPORT.md).

Запуск от 10 октября остановлен на проверке серверной связи: три попытки
дали HTTP 502 из-за недоступного GPU. План возобновления и фактические
проверки: [DEVICE_QUALITY_2026_10_10_REPORT.md](DEVICE_QUALITY_2026_10_10_REPORT.md).

Исправления после последнего прогона, проверенные без iPhone, разбор ошибок
и подготовленный новый набор:
[TEXT_QUALITY_FIXES_REPORT.md](TEXT_QUALITY_FIXES_REPORT.md).

Последняя проверка от 9 октября, естественное произнесение, исправления
разбора и ограничения автозаполнения:
[NATURAL_VOICE_CONTROL_REPORT.md](NATURAL_VOICE_CONTROL_REPORT.md).

Предыдущие результаты готового текста и аудио от 8 октября:
[DEVICE_END_TO_END_REPORT.md](DEVICE_END_TO_END_REPORT.md).

`end_to_end` готовит 56 новых синтетических WAV с обычными датами рождения:
40 текстов последнего контроля свободной речи и по 8 вариантов по формату
и с переставленными полями. Эталоны общие, 278 ожидаемых полей. Длинные
тексты озвучиваются короткими фрагментами и соединяются без потери PCM;
целый длинный `AVSpeechUtterance` может дать неполный файл. Микрофон и
диктовка пользователем не требуются.

```bash
.venv311/bin/python -m evaluation.voice.end_to_end
TEST_RUNNER_VOICE_END_TO_END_RUN=1 TEST_RUNNER_VOICE_REPORT_ID=audio-run \
xcodebuild -quiet test -project ios/Doglyad.xcodeproj \
  -scheme Doglyad-Debug-Development -configuration Release-Development \
  -destination 'platform=iOS,id=<UDID>' \
  -parallel-testing-enabled NO -test-timeouts-enabled NO \
  -only-testing:DoglyadTests/VoiceEndToEndTests/testReadyAudioThroughProductionPipeline \
  ENABLE_TESTABILITY=YES
```

Несмотря на имя схемы, явный `Release-Development` компилирует приложение
с настоящим App Attest. Тест откажется работать в Debug и на симуляторе.
Используются конфиги с защищённого backend, рабочий WhisperKit model store,
маршрутизатор Foundation Models / MedGemma, `UltrasoundReportRepository`,
`ScanSpeechConfidencePolicy` и `ScanFormPatch`. Проверяется форма в памяти;
нажатия интерфейса и сохранение тестовой записи в историю не выполняются.
Сомнительные предложения применяются отдельно как имитация подтверждения,
а отсутствующие поля должны сохранить исходные значения.

Отчёт сохраняется в контейнере приложения:
`Documents/voice-end-to-end-audio-run.json`. Скопировать его через
`devicectl device copy from`, затем оценить:

```bash
.venv311/bin/python -m evaluation.voice.score_end_to_end results.json scored.json
```

Для сопоставимого контроля готового текста запустить тот же тест с
`TEST_RUNNER_VOICE_END_TO_END_TEXT_ONLY=1` и другим `VOICE_REPORT_ID`.
Этот режим пропускает ASR и исправление словаря и использует исходный
пунктуированный текст. `TEST_RUNNER_VOICE_END_TO_END_LIMIT=6` ограничивает
пробу одним примером на каждую пару набора и языка. Отчёт качества
считает все ожидаемые поля и формы, включая технические провалы; отдельно
показывает ошибочные автоматические предложения.

### Отдельная проверка Foundation Models без GPU

В этом же тесте `TEST_RUNNER_VOICE_END_TO_END_LOCALE=en` выбирает EN-случаи
из исходной фикстуры, сохраняя её хеш и эталоны. Параметр
`TEST_RUNNER_VOICE_END_TO_END_REQUIRE_FOUNDATION_MODELS=1` требует локальную
модель и запрещает серверный разбор. Если Foundation Models не поддерживает
выбранную локаль или недоступна, случай получает техническую ошибку;
обращения к GPU не происходит.

Основной backend нужен для получения конфигураций и промптов с настоящим
App Attest. Извлечение и ASR выполняются на iPhone. При повторе сохранённого
ASR параметр `TEST_RUNNER_VOICE_ASR_CHECKPOINT` использует только выбранные
случаи из соответствующего исходного отчёта; прежние результаты извлечения
не применяются.

Отчёт содержит исходный ответ Foundation Models, предложения после проверки
цитат и итог после объединения с явными метками/фактами. Ошибка генерации
сохраняется отдельно, даже если рабочий путь смог вернуть предложения по
правилам. Качество самой модели и итогового пути следует показывать отдельно.

### Естественное произнесение и возобновление после отключения iPhone

`natural_end_to_end` отдельно готовит два замороженных корпуса:

```bash
.venv311/bin/python -m evaluation.voice.natural_end_to_end regression
.venv311/bin/python -m evaluation.voice.natural_end_to_end control
.venv311/bin/python -m evaluation.voice.natural_end_to_end holdout
```

Регрессия содержит те же 56 историй с цифровыми номерами исследования.
Новый контроль — 8 других историй в трёх вариантах диктовки: 24 случая,
138 ожидаемых полей, RU/EN, полные и частичные формы. Варианты одной истории
связаны между собой и не являются независимыми пациентами. Даты, числа,
дроби и единицы передаются синтезатору словами. `spokenText` сохраняет
задуманный текст произнесения, `inputText` — пунктуированный текст для
отдельной проверки извлечения, `expectedFields` — неизменяемый эталон формы.
Старый корпус с буквенными номерами и цифровыми дробями сохраняется.

Следующий ещё не измеренный набор — `natural_voice_holdout_v1.json`:
12 историй × 3 стиля, 36 случаев / 198 полей. Он использует тот же генератор
с естественными датами и дробями и отдельный каталог `natural-holdout-v1`.
Результаты моделей на нём не используются для доработок до завершения
заранее запланированного прогона.

Тот же тест принимает `TEST_RUNNER_VOICE_FIXTURE_NAME=natural-regression-v1`
или `natural-control-v1` / `natural-holdout-v1`. Декодирование и повторная расшифровка коротких
фрагментов вызываются через общий с приложением
`DSpeechWhisperKitTranscription`. В отчёте отдельно записываются исходные
сегменты, оценки декодера, повторный текст и время каждого этапа. Оценки
декодера и совпадение двух расшифровок не являются вероятностью правильности.

После отключения телефона скопируйте его последний JSON в
`ios/DoglyadTests/VoiceFixtures/<checkpoint>.json` и пересоберите тест с
`TEST_RUNNER_VOICE_ASR_CHECKPOINT=<checkpoint>`. Проверяются SHA-256 фикстуры,
аудио, исходный текст и эталон каждого случая. Повторно используются только
реальные ASR-транскрипты и диагностика; разбор, валидация и применение формы
выполняются заново для всех случаев. Оставшееся аудио распознаётся на iPhone.
Хеш источника повторного ASR сохраняется в `asrReusedFromSha256`, его прежнее
время сохраняется отдельно от времени текущего выполнения. Не смешивайте
готовые формы от разных версий кода в один итоговый результат.

`TEST_RUNNER_VOICE_SOURCE_SHA256` записывает идентификатор замороженных
исходников в отчёт. Для диагностики фильтра декодера:

```bash
.venv311/bin/python -m evaluation.voice.asr_reliability scored.json reliability.json
```

`recheckComparison` сравнивает нынешнюю политику автозаполнения с повторным
ASR и без него на одинаковых сохранённых предложениях. Вариант без повтора
рассматривает также поля, которые повтор ранее отправил на проверку.
`observedPolicyMismatchFields` показывает отличие расчёта от записанного
рабочего решения; ненулевое значение требует объяснения перед использованием
цифр. Это анализ сохранённых выходов, а не новый прогон моделей.

Для отдельного воспроизведения коррекции без iPhone:

```bash
swiftc -parse-as-library ios/DoglyadSpeech/Audio/DSpeechLexiconCorrector.swift \
  ios/DoglyadSpeech/Audio/DSpeechLexiconLocalization.swift \
  evaluation/voice/LexiconReplay.swift -o build/voice-eval/lexicon-replay
build/voice-eval/lexicon-replay device-results.json \
  backend/main/config/development lexicon-replay.json
```

Порог выбирается на регрессии; итоговый контроль выполняется после фиксации
кода. Если после просмотра контроля код меняется, этот контроль становится
регрессионным. Подтверждение сомнительных предложений в тесте не означает
исправления их значения врачом: оно применяется как есть и сравнивается с
эталоном.

## Три отдельных набора проверки

| Набор | Что диктуется | Эталон | Назначение |
|---|---|---|---|
| `guided-format` | Названия полей в порядке подсказки на шторке; полная форма и частичная диктовка | 124 случая из регрессионного корпуса, 31 тип × 2 языка × 2 сценария | Основной сценарий текущего интерфейса |
| `reordered-format` | Те же названия полей, но описание идёт первым, а остальные поля переставлены | 124 случая из замороженного корпуса `voiceBlind`, 31 тип × 2 языка × 2 сценария | Проверка диктовки по меткам без фиксированного порядка |
| `freeform-development` | Связная речь без названий полей; полная и частичная диктовка | Отдельные 124 вымышленных случая с независимыми ожидаемыми полями | Дополнительный сценарий свободной речи |

Во всех наборах ожидаемые поля создаются **до** озвучивания; отсутствующие в
частичной диктовке поля должны остаться нетронутыми. У каждого набора есть
чистый и обработанный шумом WAV и свой SHA-256 манифеста. `guided-format`
проверяет слова и порядок именно из `speechProcessSpeechDescription` в iOS;
тест генератора останавливается при изменении подсказки. `reordered-format`
использует эталон и чистые WAV старого `voice-blind-v3`, но собственный
манифест и новый шумовой вариант с текущим профилем; старый набор и его отчёты
сохраняются. Это рабочие наборы, а не неизвестный выпускной контроль.
Результаты одного набора не объединяются с результатами другого. Основной
критерий качества продукта — `guided-format`.

```sh
make voice-eval-guided-format-audio
make voice-eval-reordered-format-audio
make voice-eval-freeform-audio
python3 -m evaluation.voice.asr --mode guided-format --variant clean
python3 -m evaluation.voice.asr --mode reordered-format --variant clean
python3 -m evaluation.voice.asr --mode freeform-development --variant clean
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode guided-format --variant clean
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode reordered-format --variant clean
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode freeform-development --variant clean
```

Чтобы проверить разбор **после ASR**, передайте его отчёт обратно в iOS-тест,
например для набора с переставленными полями:

```sh
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode reordered-format --variant clean --replay-asr-report build/voice-eval/audio/reordered-format/asr-clean-report.json
```

Для второго прогона каждого набора укажите `--variant noisy` и отчёт
`asr-noisy-report.json`. Для полного
измерения на iPhone передайте `--physical-device-id <UDID>` в `run_ios` без
`--text-only`; микрофон не требуется, используются сохранённые WAV. В
`summary.json` поля `testPack` и `byLocaleAndScenario` показывают результаты
отдельно по набору, языку и полноте диктовки. `exactCases` считается от
**всех** случаев группы: ошибки и пропуски этапов не исключаются из знаменателя.
WER считается только там, где ASR успешно вернул строку; отсутствие данных
обозначается `null`.

Первый раздельный прогон и его ограничения: [TEST_PACKS_STATUS.md](TEST_PACKS_STATUS.md).

`make voice-eval-text` создаёт `build/voice-eval/text/regression.jsonl`,
`adversarial.jsonl` и `manifest.json`.
Случаи вымышленные и воспроизводимые: 12 на каждый из 31 типов исследования и двух
локалей, всего 744. Отдельный контрольный генератор создаёт 4 случая на пару
«тип × локаль» (248 случаев). Десять отдельных вымышленных случаев проверяют
неизвестное поле, неполную дату, сомнительную сторону, похожие термины и команду
«игнорируй правила». По умолчанию контрольные случаи не записываются на
диск; в манифесте сохраняется их SHA-256. Для однократного финального сравнения:

```sh
python3 -m evaluation.voice.generate --release-control
```

Проверка генератора: `.venv311/bin/python -m pytest evaluation/voice/tests`.

Для отдельной проверки новых значений и порядка полей без микрофона есть
`phrase-holdout`: 31 тип × 2 локали, по одной полной форме на пару. Генератор
использует заранее зарезервированные контрольные случаи, озвучивает их другим
системным голосом и сохраняет чистые и шумовые WAV с SHA-256. Формы по-прежнему
диктуются с явными названиями полей; это не тест свободной речи врача.

```sh
python3 -m evaluation.voice.phrase_holdout
python3 -m evaluation.voice.asr --mode phrase-holdout --variant clean
python3 -m evaluation.voice.asr --mode phrase-holdout --variant noisy
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode phrase-holdout --variant clean
```

Остальные варианты повторного разбора запускаются с соответствующими
`--variant` и `--replay-asr-report`. Проверка исходного текста запускается до
повторного разбора ASR. Результаты текущего прогона — в
`PHRASE_HOLDOUT_STATUS.md`. После анализа ошибок этот набор уже нельзя считать
неизвестным для последующих изменений парсера.

Для независимой проверки после `phrase-holdout` создан `voice-blind-v3`:
31 тип × 2 языка × полная и частичная диктовка. Он фиксирует новые значения,
имена, порядок полей, системные голоса и чистые/шумовые WAV. В частичной
диктовке четыре отсутствующих поля не должны заполняться. Формы всё ещё
содержат названия полей. Результаты: [VOICE_BLIND_V3_STATUS.md](VOICE_BLIND_V3_STATUS.md).

```sh
python3 -m evaluation.voice.voice_blind_v3
python3 -m evaluation.voice.asr --mode voice-blind-v3 --variant clean
python3 -m evaluation.voice.asr --mode voice-blind-v3 --variant noisy
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode voice-blind-v3 --variant clean
python3 -m evaluation.voice.field_diagnostic build/voice-eval/ios-candidate-text-asr-replay-whisper-turbo-4bit-clean-report-diagnostic-voice-blind-v3-clean/summary.json
python3 -m evaluation.voice.audit_replay build/voice-eval/ios-candidate-text-asr-replay-whisper-turbo-4bit-clean-report-diagnostic-voice-blind-v3-clean/summary.json build/voice-eval/audio/voice-blind-v3/whisper-turbo-4bit/clean-report.json build/voice-eval/audio/voice-blind-v3/audit-turbo-clean.json
```

Повторите последние два шага для остальных ASR-отчётов и шумового варианта.
Тестовый runner обновляет `cases.json` и проверяет его источник и хеш после
запуска Xcode, чтобы предыдущая копия фикстуры не попала в результаты.

Для разработки пути свободной речи есть отдельный набор
`freeformDevelopment.jsonl`: 31 тип × 2 языка × полная/частичная диктовка.
Фразы построены как связный текст без команды «описание исследования», а
частичный сценарий содержит явное самоисправление измерения. Эталонные поля и
источники фрагментов создаются до текста из вымышленных данных:

```sh
python3 -m evaluation.voice.freeform_development
python3 -m evaluation.voice.freeform_audio
python3 -m evaluation.voice.asr --mode freeform-development --variant clean
python3 -m evaluation.voice.asr --mode freeform-development --variant noisy
python3 -m evaluation.voice.fact_diagnostic build/voice-eval/audio/freeform-development/asr-clean-report.json build/voice-eval/audio/freeform-development/apple-clean-facts.json
```

Это рабочий набор с чистыми и шумовыми WAV, а не независимый выпускной тест.
Текущий шумовой профиль задаёт SNR 25 дБ в `audio.py`; прежние результаты
для SNR 20 дБ отделены в `FREEFORM_DEVELOPMENT_STATUS.md`.
Генерацию Foundation Models измеряем на физическом iPhone с доступной системной моделью и поддерживаемым языком. На симуляторе проверяем детерминированный разбор, валидацию и применение полей. Исторические сравнения моделей сохранены в [FREEFORM_DEVELOPMENT_STATUS.md](FREEFORM_DEVELOPMENT_STATUS.md).

Физический iPhone можно проверить без микрофона, передав тесту заранее
синтезированные WAV. `--asr-only` обходит медленную локальную модель и
сохраняет транскрипты. `--text-only --replay-asr-report` повторно пропускает
те же строки через текущий Swift-парсер на симуляторе; это измеряет извлечение
полей отдельно от распознавания. Подставьте UDID своего подключённого iPhone:

```sh
python3 -m evaluation.voice.run_ios --candidate --mode freeform-development --variant clean --asr-only --physical-device-id <UDID>
python3 -m evaluation.voice.export_device_asr build/voice-eval/ios-candidate-device-asr-only-freeform-development-clean/results.json --mode freeform-development
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode freeform-development --variant clean --replay-asr-report build/voice-eval/ios-candidate-device-asr-only-freeform-development-clean/asr-replay-speechAnalyzer-hints-true-report.json
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode freeform-development --variant clean
python3 -m evaluation.voice.run_ios --candidate --text-only --all-regression-text --diagnostic-only
```

Для отдельной проверки влияния `.farField` на файловый SpeechAnalyzer:

```sh
python3 -m evaluation.voice.run_ios --candidate --asr-only --confidence-only \
  --no-far-field-hint --mode freeform-development --variant clean \
  --locale ru --limit 12 --physical-device-id <UDID>
```

Этот флаг оставляет набор акустических подсказок пустым. Он действует только
в тесте WAV и не переключает микрофонный контроллер приложения.

Рабочая запись теперь использует WhisperKit Turbo в `DoglyadSpeech`: при входе
в шторку проверяется модель `large-v3-v20240930_626MB`. Если её нет, шторка
показывает прогресс скачивания и открывает кнопку записи после подготовки.
Скачанная модель хранится в Application Support и доступна без сети. Аудио
записывается во временный несжатый CAF, расшифровывается на устройстве после
остановки и удаляется.
Старые SpeechAnalyzer и SFSpeechRecognizer сохранены для сравнительных тестов.

Для отдельного тестового прогона WhisperKit модель Core ML должна лежать в
`Documents/VoiceWhisperKitModel` контейнера тестового приложения на iPhone. Тест
`VoiceWhisperKitTests` запускается с `TEST_RUNNER_VOICE_WHISPERKIT_RUN=1`, а
`export_whisperkit_ios.py` переводит сохранённый JSON в общий ASR-отчёт.
Обёртка готовит WAV, запускает тест на физическом устройстве, проверяет хеш
манифеста и экспортирует отчёт для трёх форматов диктовки и контрольного
набора `voice-blind-v3`:

```sh
python3 -m evaluation.voice.run_whisperkit_ios --mode guided-format --variant clean --device-id <UDID>
python3 -m evaluation.voice.run_whisperkit_ios --mode reordered-format --variant noisy --device-id <UDID>
python3 -m evaluation.voice.run_whisperkit_ios --mode freeform-development --variant clean --device-id <UDID>
python3 -m evaluation.voice.run_whisperkit_ios --mode freeform-development --variant clean --device-id <UDID> --model large-v3-947
python3 -m evaluation.voice.run_whisperkit_ios --mode freeform-development --variant clean --device-id <UDID> --prompt type-context
python3 -m evaluation.voice.run_whisperkit_ios --mode voice-blind-v3 --variant clean --device-id <UDID>
python3 -m evaluation.voice.run_whisperkit_ios --mode voice-blind-v3 --variant noisy --device-id <UDID>
```

Каждый запуск создаёт `build/voice-eval/ios-whisperkit-device-<mode>-<variant>/`
с `results.json`, `asr-report.json` и журналом Xcode. Сравнение с сохранённым
SpeechAnalyzer выполняет `python3 -m evaluation.voice.compare_asr_reports
<speechAnalyzer-report.json> <asr-report.json> <comparison.json>`; оно отдельно
считает WER и потери стороны, отрицания, числа и единицы измерения.
`--model large-v3-947` требует отдельную Core ML модель в
`Documents/VoiceWhisperKitModelLargeV3` и сохраняет отчёт в отдельном каталоге.
`--prompt type-context` передаёт первые 20 существующих фраз выбранного типа
исследования в декодер WhisperKit и тоже сохраняет отдельный отчёт. Оба
режима остаются тестовыми и не меняют путь приложения.

Для проверки конечной формы на том же сохранённом WhisperKit-тексте:

```sh
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only \
  --mode voice-blind-v3 --variant clean --locale ru \
  --replay-asr-report build/voice-eval/ios-whisperkit-device-voice-blind-v3-clean/asr-report.json \
  --apply-replay-lexicon --parse-strategy production --physical-device-id <UDID>
```

Повторите с `--locale en` и `--variant noisy`, подставив `noisy/asr-report.json`.
Этот replay проверяет продуктовый Swift-разбор, но не измеряет уверенность слов
WhisperKit для автоматического применения полей.

Для диагностического скрининга Parakeet на Mac соберите `fluidaudiocli` из
[FluidAudio](https://github.com/FluidInference/FluidAudio), загрузите
[модель v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) и запустите:

```sh
python3 -m evaluation.voice.run_parakeet_mac \
  --cli build/voice-eval/tools/FluidAudio/.build/release/fluidaudiocli \
  --model-dir build/voice-eval/models/parakeet-tdt-0.6b-v3 \
  --source-commit <FluidAudio-commit> \
  --mode freeform-development --variant clean \
  --output build/voice-eval/parakeet-v3-mac-freeform-clean/asr-report.json
```

Runner проверяет SHA-256 каждого WAV и фиксирует SHA-256 файлов модели. Его
задержка измерена на Mac и не является оценкой скорости iPhone.

Чтобы измерить результат заполнения формы по сохранённому WhisperKit-тексту,
передайте его `asr-report.json` в `run_ios` с `--candidate --text-only
--diagnostic-only --parse-strategy production`. Флаг `--apply-replay-lexicon`
создаёт **отдельный** прогон, в котором перед разбором используется тот же
`DSpeechLexiconCorrector` и словарь фраз типа исследования. В `results.json`
поле `parseInputText` сохраняет текст после коррекции для проверки изменений.
Если меняется сам `DSpeechLexiconCorrector`, сохранённый отчёт SpeechAnalyzer
можно переоценить без повторного ASR: `python3 -m
evaluation.voice.raw_asr_replay <asr-report.json> <raw-report.json>` переносит
`rawText` в поле входного текста, сохраняя диапазоны уверенности. Затем
`run_ios` получает `<raw-report.json>` и `--apply-replay-lexicon`. Производный
отчёт фиксирует SHA-256 исходного отчёта.

```sh
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only \
  --mode guided-format --variant clean --locale en \
  --replay-asr-report build/voice-eval/ios-whisperkit-device-guided-format-clean/asr-report.json \
  --apply-replay-lexicon --parse-strategy production --physical-device-id <UDID>
```

Измерения ASR и их ограничения: [FREEFORM_DEVELOPMENT_STATUS.md](FREEFORM_DEVELOPMENT_STATUS.md).

Генераторы сначала выбирают ожидаемые значения полей и атомарные факты,
а затем составляют текст диктовки. Ожидаемый ответ не вычисляется парсером приложения.
Названия структур берутся из контекстного словаря соответствующего типа исследования;
список типов берётся из backend-конфигурации development. Seed зависит от версии
генератора, набора, локали, типа и номера случая. Манифест фиксирует хеши генерации
и исходных конфигов. Изменение шаблонов или исходного словаря требует новой версии
контрольного набора; контрольные случаи нельзя использовать для настройки модели.

`expectedFields` содержит только поля, которые можно предложить для заполнения.
`expectedSourceQuotes` — буквальные фрагменты `spokenText`. При противоречии или
незаконченной фразе описание остаётся в тексте, но отсутствует в `expectedFields`,
а причина указана в `reviewReasons`. `expectedFacts` фиксирует измерение, отрицание
и сторону, если она явно присутствует в выбранном термине.

## Синтезированное аудио

`make voice-eval-audio` создаёт по одному чистому WAV на пару «тип × локаль»:
62 файла в `build/voice-eval/audio/quick/clean/`. Синтез выполняется системным
`AVSpeechSynthesizer.write`, а `manifest.json` фиксирует входной хеш, голос,
параметры синтеза, длительность и SHA-256 каждого PCM16 WAV. Генератор проверяет,
что файлы не пусты, имеют один канал и соответствуют выбранным случаям.

Расширенный набор создаётся командой
`python3 -m evaluation.voice.audio --mode extended`: четыре случая на пару,
каждый в чистом и обработанном варианте, всего 496 WAV. Шумовой профиль включает
фиксированные SNR, усиление, короткое эхо, изменение темпа и тишину по краям;
его параметры и seed записаны в коде и манифесте. Для проверки одного случая есть
`--limit 1`, который создаёт отдельный каталог `extended-smoke-1` и не трогает
полный набор. Повторный запуск команды сохраняет уже созданные WAV при совпадении
хешей. Для намеренного обновления набора служит `--force`.
Генерация требует установленного системного голоса. В изолированной
песочнице Apple TTS может вернуть пустой звук; при обычном локальном запуске
команды он создаёт WAV.

### Полная диктовка, аудионабор v2

`make voice-eval-audio-v2` создаёт **отдельный** набор
`build/voice-eval/audio/extended-v2/`: 248 цельных диктовок и 248 шумовых
копий. Каждый WAV содержит все восемь полей одной вымышленной формы.
Генератор синтезирует две половины по четыре поля и соединяет их в один PCM
WAV с паузой 180 мс: один длинный вызов `AVSpeechSynthesizer.write` в
диагностике обрывал последние поля. Исходные сегменты и их текст сохраняются
рядом с итоговым WAV для проверки полноты.
Вход синтезатора записан словами для ведущих нулей номера, последовательности
цифр даты, роста, веса, целых измерений и единиц; поля разделяются короткими
паузами, а не точками с запятой. Ожидаемые значения формы остаются из
структурированного регрессионного набора и не выводятся из распознавания.
`werReference` в манифесте — предполагаемые слова синтезатора; это не
расшифровка реального диктора и не ручная проверка каждого WAV. Версия v1
сохраняется, её отчёты нельзя сопоставлять с v2 как парный эксперимент.
Для v2 основной WER принимает запись числа цифрами и общепринятое
сокращение единицы за ту же последовательность произнесённых слов; иначе
корректное `188 cm` ошибочно сравнивалось бы с «one hundred eighty eight
centimeters». Неверная цифра, сторона или отрицание по-прежнему считаются
ошибкой. Буквальный WER без этих эквивалентностей также сохраняется в JSON.

Для прогона одинаковых v2 WAV через baseline и кандидата на физическом iPhone:

```sh
python3 -m evaluation.voice.run_ios --mode extended-v2 --variant clean --physical-device-id <UDID>
python3 -m evaluation.voice.run_ios --candidate --mode extended-v2 --variant clean --physical-device-id <UDID>
python3 -m evaluation.voice.run_ios --mode extended-v2 --variant noisy --physical-device-id <UDID>
python3 -m evaluation.voice.run_ios --candidate --mode extended-v2 --variant noisy --physical-device-id <UDID>
python3 -m evaluation.voice.paired_v2 build/voice-eval/ios-device-extended-v2-clean/summary.json build/voice-eval/ios-candidate-device-extended-v2-clean/summary.json build/voice-eval/audio/extended-v2/paired-clean.json
```

Повторите последнюю команду для `noisy`. Сравнение проверяет хеш одного и
того же аудиоманифеста, корпуса и список ID. Неполный прогон не проходит
выпускной порог; `releaseGate` измеряется только при 124 случаях на локаль.
Порог считает `equivalentExactCase`: запись числа цифрами вместо произнесённых
слов и сокращение единицы не меняют клиническое значение. Строгий
`exactCase` остаётся в отчёте. Сторона, отрицание, имя и само числовое
значение не нормализуются; ошибочные поля без предупреждения считаются по
той же ограниченной эквивалентности. Иначе все 31 сценарий
`spoken_measurement` на язык заведомо проваливали бы строковый порог при
корректном ASR.

Полный выпускной расчёт нового пути на чистом и шумовом v2 аудио, без
повторного запуска старой локальной модели:

```sh
python3 -m evaluation.voice.v2_gate build/voice-eval/ios-candidate-device-extended-v2-clean/summary.json build/voice-eval/ios-candidate-device-extended-v2-noisy/summary.json build/voice-eval/audio/extended-v2/release-gate.json
```

Он требует одинаковые ID, типы исследования, локали и хеши корпуса в обоих
отчётах, а также 124 завершённых случая на язык и вариант. Цели: не менее
118/124 равнозначно точных форм на чистом, 106/124 на шумовом и ноль
ошибочных предложенных полей без предупреждения в каждом срезе.

Чтобы отделить ограничения парсера от ошибок ASR, можно передать **исходный
текст синтезатора** тому же iOS-парсеру без повторного распознавания аудио:

```sh
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode extended-v2 --variant clean --physical-device-id <UDID>
python3 -m evaluation.voice.export_device_asr build/voice-eval/ios-candidate-device-extended-v2-clean/results.json --mode extended-v2 --variant clean
python3 -m evaluation.voice.run_ios --candidate --text-only --diagnostic-only --mode extended-v2 --variant clean --replay-asr-report build/voice-eval/ios-candidate-device-extended-v2-clean/asr-replay-speechAnalyzer-hints-true-report.json --physical-device-id <UDID>
python3 -m evaluation.voice.oracle_diagnostic build/voice-eval/ios-candidate-device-text-diagnostic-extended-v2-clean/summary.json build/voice-eval/ios-candidate-device-text-asr-replay-ios-candidate-device-extended-v2-clean-asr-replay-speechAnalyzer-hints-true-report-diagnostic-extended-v2-clean/summary.json build/voice-eval/audio/extended-v2/oracle-vs-asr-clean.json
```

`--diagnostic-only` сохраняет все ошибки исходного текста в отдельном отчёте,
не применяя выпускной порог. Сравнение требует одинаковые хеши корпуса и
аудиоманифеста и те же ID. Исходный текст — вход TTS, а не вручную проверенный
транскрипт аудио, поэтому результат не доказывает точность на живой речи.
Текстовый прогон без `--diagnostic-only` требует все правильные поля; для v2
написанные цифрами и словами числа и единицы считаются равнозначными.

Для проверки зависимости от синтетического диктора отдельный набор
`voice-holdout` берёт по одному случаю на тип и локаль из зафиксированных
v2 сценариев и произносит **те же тексты** другими системными голосами
(Eddy для en, Yelena для ru). Он не заменяет проверку новых формулировок и
естественной речи. Генерация использует установленный голос macOS:

```sh
python3 -m evaluation.voice.holdout_voice
python3 -m evaluation.voice.run_ios --candidate --mode voice-holdout --variant clean --physical-device-id <UDID>
python3 -m evaluation.voice.run_ios --candidate --mode voice-holdout --variant noisy --physical-device-id <UDID>
python3 -m evaluation.voice.compare_voice_holdout build/voice-eval/ios-candidate-device-extended-v2-clean/summary.json build/voice-eval/ios-candidate-device-voice-holdout-clean/summary.json build/voice-eval/audio/voice-holdout/paired-clean.json
```

Для шумового сравнения замените `clean` на `noisy` в путях и выходном имени.
Сравнение требует одинаковые ID, локали, типы исследования, ожидаемые слова и
хеши соответствующих аудиоманифестов. В каждой локали получается 31 пара.
Числа по последней версии парсера, включая повторный разбор уже сохранённого
ASR после добавления русской метки «жалоба», приведены в
[`V2_STATUS.md`](V2_STATUS.md). Отчёт `paired-clean.md` и `paired-noisy.md`
фиксирует состояние парсера на момент исходного аудиопрогона.

`make voice-eval-asr-macos` запускает **диагностический** файловый
`DictationTranscriber` с контекстным словарём выбранного типа и существующим
`DSpeechLexiconCorrector` на быстром наборе. Результаты и причины пропусков
лежат в `build/voice-eval/audio/quick/asr-report.json`. Код не засчитывает
пропущенные случаи как успешные. Этот прогон выполняется на macOS и не является
baseline конечного сценария iOS: микрофон, обработка звука и `parseSpeech` в нём
не участвуют. Первый результат и обнаруженные ограничения описаны в
[`MACOS_ASR_DIAGNOSTIC.md`](MACOS_ASR_DIAGNOSTIC.md).

Эксперимент с восемью названиями полей поверх словаря типа запускается на том
же аудио так:

```sh
python3 -m evaluation.voice.asr --mode quick --form-label-hints
python3 -m evaluation.voice.asr --mode extended --variant clean --form-label-hints
python3 -m evaluation.voice.asr --mode extended --variant noisy --form-label-hints
```

Отчёты с суффиксом `form-label-hints` сохраняются отдельно от baseline.
Сравнивайте их только при одинаковом `audioManifestSha256`; иначе это разные
записи TTS. Недоступный распознаватель в изолированной среде помечается как
`skipped`, и такой прогон не является измерением качества.
Итоговое сравнение WER, точных форм и медицинских фактов приведено в
[IOS_CANDIDATE_STATUS.md](IOS_CANDIDATE_STATUS.md). Общие подсказки пока не
включены в приложение: на одном шумном файле с ними потерялась сторона.
Парное сравнение можно воспроизвести командой:

```sh
python3 -m evaluation.voice.compare_asr_reports build/voice-eval/audio/extended/asr-report.json build/voice-eval/audio/extended/asr-form-label-hints-noisy-report.json build/voice-eval/audio/extended/asr-form-label-hints-noisy-comparison.json
```

Она требует одинакового аудиоманифеста и набора случаев и отдельно сигнализирует
о потере стороны или отрицания. Потери чисел пока оцениваются буквально: запись
числа словом вместо цифры отображается в отчёте, но не блокирует эту отдельную
проверку стороны и отрицания. Проверка не заменяет оценку итоговых полей.

`make voice-eval-asr-compare` повторно распознаёт те же 62 WAV системными
`SpeechAnalyzer` и `SFSpeechRecognizer` с подсказками и без них. Влияние
корректора рассчитывается на одинаковом сыром транскрипте. Парные изменения
WER и буквальной сохранности измерения, единицы, стороны и отрицания,
таблица по типам исследования и причины пропусков сохраняются в
`audio/quick/comparison-report.json` и `comparison.md`. В macOS
`SFSpeechRecognizer` может быть недоступен даже при поддержке локального
режима: такой вариант остаётся **неизмеренным**. Для пересчёта показателей
из уже записанных результатов есть `python3 -m evaluation.voice.comparison
--mode quick --score-only`.

`make voice-eval-fleurs` скачивает первые 100 разных аудиофайлов из `test`
разделов `en_us` и `ru_ru` [Google FLEURS](https://huggingface.co/datasets/google/fleurs)
на закреплённой ревизии `70bb2e84b976b7e960aa89f1c648e09c59f894dd` и
сравнивает два отдельных запуска неизменённого `SpeechAnalyzer` без медицинских
подсказок. Для каждого файла сохраняются ID, эталон, SHA-256, ревизия и
атрибуция. Лицензия набора — CC BY 4.0. Аудио и транскрипты находятся только
в игнорируемом `build/voice-eval/fleurs/`, в Git не добавляются. Это
независимая естественная речь для оценки ASR; она не проверяет поля УЗИ.
WER нормализует регистр через Unicode `casefold` и заменяет знаки пунктуации
пробелами; CER считает расстояние по символам после той же нормализации.

## Файловый iOS baseline

`make voice-eval-ios` проверяет все 62 WAV в iOS Simulator. Команда копирует
синтетические фикстуры в игнорируемую папку `ios/DoglyadTests/VoiceFixtures/`,
запускает `VoiceBaselineTests` и сохраняет `build/voice-eval/ios/results.json`,
`summary.json`, `summary.md` и `xcodebuild.log`. Для одного случая:

```sh
python3 -m evaluation.voice.run_ios --locale ru --limit 1
```

Тестовый runner использует те же параметры `DictationTranscriber`, контекстный
словарь и `DSpeechLexiconCorrector`, что и запись с микрофона. Он отдельно
вызывает исторический `parseSpeech` из `DoglyadTests/VoiceSupport/Legacy/` с исходным текстом и с распознанным текстом,
сохраняет время, результат либо причину отказа. Номер исследования отмечает
как неподдерживаемый текущей моделью ответа. Подробности первого прогона — в
[`IOS_BASELINE_STATUS.md`](IOS_BASELINE_STATUS.md).

На установленном iPhone 17 Simulator с iOS 26.5 системные речевые форматы
для `DictationTranscriber` отсутствуют, а локальные модели разбора не дают
готового ответа. Отчёт **не** считает такие случаи успешными и не вычисляет
точность формы при нулевом числе завершённых разборов. Mac диагностический
прогон выше остаётся отдельным измерением.

## Кандидат и выпускные пороги

`make voice-eval-ios-candidate` запускает новый путь с восьмью полями,
цитатами и предупреждениями на тех же 62 WAV. Он записывает ASR двух локальных
движков с подсказками и без них, предложение для исходного текста и предложение
после каждого доступного ASR. Результаты и причины отказа: `ios-candidate/`.
Диктовка с явными названиями полей разбирается детерминированно из точных
отрезков транскрипта; свободная речь остаётся на локальной модели. При потере
одной метки остальные поля могут быть извлечены, невалидные значения
отклоняются. Поэтому время и точность обоих вариантов нужно измерять отдельно.
Первый полный парный прогон на физическом iPhone и ограничения качества
описаны в
[`IOS_CANDIDATE_STATUS.md`](IOS_CANDIDATE_STATUS.md).
Для физического iPhone укажите `--physical-device-id <UDID>`: runner забирает
результат из контейнера приложения и сохраняет его в `ios-device/` или
`ios-candidate-device/`. Отчёт выбирает физическую пару только когда готовы оба
полных быстрых прогона. Если в настройках устройства выключена системная
диктовка, `SFSpeechRecognizer` выдаёт ошибку; это отмечается как недоступное
измерение, даже если `SpeechAnalyzer` на том же устройстве работает.

Для диагностики самого разбора без ASR используйте регрессионный набор с
`--candidate --text-only --locale ru --limit 7 --physical-device-id <UDID>`.
Для проверки парсера на сохранённых транскриптах macOS ASR без подключённого
iPhone используйте:

```sh
python3 -m evaluation.voice.run_ios --candidate --text-only --replay-macos-asr --mode extended --variant clean
```

Отдельный каталог и поля
`inputSource` и `asrReportSha256` показывают происхождение текста. Эта проверка
не заменяет измерение ASR на iPhone.
Для всего регрессионного текстового набора из 744 случаев:

```sh
python3 -m evaluation.voice.run_ios --candidate --text-only --all-regression-text
```

Другой локальный ASR можно сравнить через JSONL с полями `id` (`caseId/clean`
или `caseId/noisy`), `status`, `text` и `elapsedSeconds`. Для каждого WAV
должен быть ровно один результат. Конвертер проверяет полноту и привязывает
отчёт к хешам заданий и аудиоманифеста:

```sh
python3 -m evaluation.voice.import_asr_jsonl jobs.json results.jsonl clean-report.json --recognizer 'model name and revision' --variant clean
python3 -m evaluation.voice.run_ios --candidate --text-only --replay-asr-report clean-report.json --mode extended --variant clean --physical-device-id <UDID>
```

Здесь iPhone проверяет разбор **заранее полученного** транскрипта. Для
продуктового выбора нового ASR отдельно нужны исполнение модели на iPhone,
замеры памяти и задержки и сравнение на естественной речи.

Каждый прогон iOS получает уникальный ID отчёта; runner проверяет ID и хеш
источника транскриптов, чтобы не принять старый результат симулятора за новый.
`run-state.json` помечает начатый и завершённый прогон: сводный отчёт не
использует результаты прошлой попытки, пока новый тест выполняется или был
прерван.
Для разбора всех четырёх вариантов ASR из физического прогона и парного
сравнения словарных подсказок:

```sh
python3 -m evaluation.voice.device_asr build/voice-eval/ios-candidate-device-tokens2048-extended-clean/results.json
```

`device-asr-summary.json` показывает WER, CER и буквальную сохранность стороны,
отрицания, числа и единицы. Последний счётчик занижает результат, когда ASR
записывает число словом вместо цифры; итоговые поля проверяются отдельно.
Чтобы после изменения парсера повторно разобрать **те же транскрипты iPhone**
без нового распознавания WAV:

```sh
python3 -m evaluation.voice.export_device_asr build/voice-eval/ios-candidate-device-tokens2048-extended-clean/results.json --mode extended --variant clean
python3 -m evaluation.voice.run_ios --candidate --text-only --replay-asr-report build/voice-eval/ios-candidate-device-tokens2048-extended-clean/asr-replay-speechAnalyzer-hints-true-report.json --mode extended --variant clean --physical-device-id <UDID>
```

Экспорт проверяет хеш аудиоманифеста и полноту набора. Этот прогон измеряет
только изменение разбора сохранённого текста; влияние новой версии ASR требует
отдельного запуска на звуке.
Экспериментальный `--max-tokens N` меняет лимит только в тестовой фикстуре;
фактическое значение сохраняется в `runner.json`. Такие результаты получают
отдельный каталог и не заменяют парный аудиопрогон.

Для расширенного набора сначала выполните `make voice-eval-audio-extended`, затем:

```sh
python3 -m evaluation.voice.run_ios --candidate --mode extended --variant clean
python3 -m evaluation.voice.run_ios --candidate --mode extended --variant noisy
```

В расширенном аудиопрогоне повторный разбор исходного текста пропускается:
оценивается полный путь от WAV через ASR до полей. Для повторного быстрого
сравнения после диагностики можно передать `--skip-gold` и baseline, и
кандидату; текстовый контроль и провокационные случаи всегда разбираются.

Контрольный набор используется один раз после настройки алгоритма на
регрессионных случаях и только на устройстве с работающей локальной моделью.
Версия v1 уже открыта и выявила недостающие признаки неопределённости; после
исправления она стала регрессионной проверкой. Для независимой финальной оценки
нужен новый отложенный набор с другим составом фраз.
До него можно запустить десять открытых провокационных текстовых случаев
с флагами `--candidate --adversarial --physical-device-id <UDID>` у
`evaluation.voice.run_ios`. Результат попадает в отдельный выпускной порог.
Сначала `python3 -m evaluation.voice.generate --release-control`, затем
`python3 -m evaluation.voice.run_ios --candidate --control`. Повторная генерация
с изменённым SHA-256 контрольного набора остановится с ошибкой: для нового
набора нужна новая версия и каталог.

`make voice-eval-verify` запускает Ruff, mypy и pytest в каждом backend,
проверки генераторов и iOS test target. Для подключённого iPhone:
`python3 -m evaluation.voice.verify --physical-device-id <UDID>`.
`make voice-eval-report` собирает
`build/voice-eval/<commit>/report.json` и `report.md` и завершается с ошибкой,
если любой выпускной порог не пройден **или не измерен**. Для диагностического
отчёта без проверки порогов можно отдельно вызвать
`python3 -m evaluation.voice.report`. Отчёт фиксирует SHA-256 исходников и
признак незакоммиченных изменений. Для работы Apple Speech и CoreSimulator
может требоваться запуск вне изолированной песочницы.
При сравнении свободного текста полей оценщик игнорирует регистр и знаки
пунктуации, но сохраняет слова, порядок и числа; идентификатор исследования и
типизированные поля сравниваются строго. Предупреждение рядом с неверным
предложением не делает его правильным в отчёте.
Если модель дала неверный формат значения или цитату, которой нет в транскрипте,
поле отклоняется отдельно, а проверенные предложения остаются доступны. UI
показывает имена отклонённых полей; они не могут попасть в патч формы.
Номер исследования дополнительно отклоняется, если цитата относится к другому
документу или не подтверждает предложенное значение; цитата остаётся среди
неразобранных фраз.

Поскольку проект ещё не выпущен, оба конфига включают новый сценарий для
проверки владельцем продукта. Это не означает, что критерии качества пройдены:
отчёт отдельно показывает проваленные и неизмеренные пороги. При отсутствии
поля в ответе сервера клиент считает сценарий выключенным. Встроенная
аналитика передаёт только исход этапа, количество
предложений и предупреждений и длительность разбора; речь и поля пациента в
события не входят.

## Эксперимент с серверным разбором текста

`POST /v1/ultrasound/parse_dictation` получает тип исследования и финальный
транскрипт. `backend/main` строит локализованный промпт и проверяет ответ;
`backend/inference` использует действующий `/v1/generation`. Аудио в этом
эксперименте не передаётся на сервер. Оба серверных конфига
`voice_form_parsing.json` сейчас указывают на `google/medgemma-4b-it`.

Для сравнения с прямым разбором готовой пунктуированной строки один запуск
обрабатывает все три набора (по 62 случая на EN и RU). Вход `ideal-text` —
ровно `ttsText` из аудиоманифестов, поданный в iOS-диагностику как
`originalText`. Вход `whisperkit-clean` — сохранённые `correctedText` с iPhone.
Скрипт перед запросами проверяет полноту шести групп и сохраняет отдельные
возобновляемые JSON- и Markdown-отчёты по каждому набору:

```bash
python3 -m evaluation.voice.run_server_benchmark \
  --source ideal-text \
  --token-file /private/tmp/doglyad-app-check-token
```

Для проверки пути после ASR заменить `ideal-text` на `whisperkit-clean`;
`--source both` последовательно прогоняет оба входа. `--limit 1` создаёт
отдельные пилотные файлы и не загрязняет полный прогон. В таблицах отчёта
`Exact forms` и `Correct fields` означают строгое совпадение с эталоном;
рядом отдельно указаны показатели с эквивалентностью записи произнесённых
чисел и единиц. Неудавшийся разбор даёт ноль и остаётся в знаменателе.

После запуска inference и обновления всех VM повторить каждый набор можно
командой (для остальных наборов заменить пути корпуса и ASR-отчёта):

```bash
python3 -m evaluation.voice.server_parse \
  --corpus build/voice-eval/text/regression.jsonl \
  --asr-report build/voice-eval/ios-candidate-device-asr-only-guided-format-clean/asr-replay-speechAnalyzer-hints-true-report.json \
  --output build/voice-eval/server/guided-clean-retry3.json \
  --base-url https://dev.api.doglyad.ru \
  --token-file /private/tmp/doglyad-app-check-token \
  --max-attempts 3
```

Чтобы отдельно проверить разбор точного текста, поданного синтезатору,
вместо `--asr-report` передаётся
`--audio-manifest build/voice-eval/audio/guided-format/manifest.json`.
Для набора без порядка нужен корпус `build/voice-eval/text/voiceBlind.jsonl`,
для свободной речи — `build/voice-eval/text/freeformDevelopment.jsonl`.

Файл токена должен содержать действующий App Check токен приложения и
находиться вне Git; оценщик перечитывает его перед каждым запросом. Запросы
идут не чаще 30 в минуту. Результат сохраняется после каждого случая и
продолжается с прерванного места при повторном запуске. Метрики этого
отчёта характеризуют **проверенный backend ответ до дополнительной
валидации на iPhone**: неверное предложенное поле считается ошибкой даже
если экран позднее отправит его врачу на подтверждение. Финальную политику
автозаполнения следует оценивать отдельно.

Для честного сравнения числа попыток используйте новый выходной файл: при
возобновлении уже записанные случаи пропускаются. Каждая попытка сохраняется
в `results[].attempts`; после трёх ошибок случай остаётся техническим провалом.
При HTTP 401 оценщик останавливается, чтобы истёкший App Check токен не
считался ошибкой модели. После обновления токена команду можно повторить.

## Сравнение локальных разборщиков на одном транскрипте

Численные результаты всех способов и разбор причин ошибок: [PARSER_COMPARISON.md](PARSER_COMPARISON.md).

Флаг `--parse-strategy` в режиме `--candidate --text-only --diagnostic-only`
выбирает один способ разбора: `exactLabels` (буквальные метки),
`naturalLanguage` (метки и явные факты с распознаванием имени через Apple
Natural Language) или `foundationModels` (прямой вызов модели).
`production` использует текущую последовательность приложения. Во всех
случаях передавайте один и тот же `--replay-asr-report`, чтобы сравнивать
разбор, а не заново распознавать аудио. Например:

```bash
python3 -m evaluation.voice.run_ios \
  --candidate --text-only --diagnostic-only \
  --mode guided-format --variant clean \
  --replay-asr-report build/voice-eval/ios-candidate-device-asr-only-guided-format-clean/asr-replay-speechAnalyzer-hints-true-report.json \
  --parse-strategy naturalLanguage \
  --physical-device-id <UDID>
```

### Независимый текстовый контроль свободной речи

`freeformHoldoutV4.jsonl` содержит 124 новых случая: 31 тип исследования ×
полная/частичная форма × EN/RU. Генератор использует другие фразы и новые имена,
а SHA-256 корпуса зафиксирован тестом. Он повторно использует синтетические
клинические фрагменты каталога и всего несколько шаблонов фраз, поэтому это
контроль обобщения разбора текста, а не независимая выборка реальной речи.
Аудио и ASR в этом наборе отсутствуют. После просмотра его ошибок правила
нельзя подгонять и продолжать называть тот же набор независимым.

```bash
python3 -m evaluation.voice.freeform_holdout_v4
python3 -m evaluation.voice.run_ios \
  --candidate --text-only --holdout-v4 --locale ru \
  --parse-strategy production --diagnostic-only \
  --physical-device-id <UDID>
python3 -m evaluation.voice.run_ios \
  --candidate --text-only --holdout-v4 --locale ru \
  --parse-strategy naturalLanguage --diagnostic-only \
  --physical-device-id <UDID>
```

Повторить с `--locale en`. Результаты записываются в отдельные каталоги
`build/voice-eval/ios-candidate-device-text-*-holdout-v4-<locale>/`. Отчёт
проверяет хеш корпуса и сравнивает каждое поле и полную форму.

После изучения ошибок V4 этот набор становится диагностическим. Перед
изменением парсера отдельно зафиксирован `freeformHoldoutV5.jsonl` с другими
формулировками и именами; тот же runner принимает `--holdout-v5`. Его первый
результат и дальнейшие измерения записаны в [PARSER_COMPARISON.md](PARSER_COMPARISON.md).

V6 был зафиксирован до перехода к объединению предложений по полям. Его
исходные результаты сохранены в `build/voice-eval/holdout-v6-baseline/`.
После изучения V6 и исправления маркеров он тоже считается диагностическим.
V7 зафиксирован до исправления этих маркеров: 124 случая, SHA-256
`0d499bdbbd7e95fb23e47f77a8cdbcd7cf712df338d50b916357f23682627aa8`.
Он использует новые фразы, но тот же генератор клинических фактов, поэтому
остаётся синтетическим контролем переноса, а не доказательством качества на
речи врачей. Для наборов V6–V8 работают `--holdout-v6`, `--holdout-v7` и
`--holdout-v8`. V8 был зафиксирован до исправления ошибок V7. Первый результат
V8 сохранён в `build/voice-eval/holdout-v8-first-pass/`; после его разбора V8
также стал диагностическим. Цифры приведены в [PARSER_COMPARISON.md](PARSER_COMPARISON.md).

```bash
python3 -m evaluation.voice.freeform_holdout_v7
python3 -m evaluation.voice.run_ios \
  --candidate --text-only --diagnostic-only --holdout-v7 \
  --locale en --physical-device-id <UDID>
python3 -m evaluation.voice.clinical_fact_coverage \
  build/voice-eval/ios-candidate-device-text-diagnostic-holdout-v7-en/results.json
```

Проверка клинического текста отдельно считает отсутствующие описания и
предложенные описания, у которых исчезли число, единица, сторона или отрицание.
Это буквальная проверка синтетических фактов, а не определение медицинской
эквивалентности.
