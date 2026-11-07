# Карта покрытия модулей

Это полнота описания сценариев по найденным callback-методам, а не процент покрытия кода или доказательство прохождения тестов.

`maestro` — весь сценарий связан с flows; `mixed` — flows и обязательные проверки XCTest; `partial` — автоматизирована часть; `manual` — нужна ручная проверка или подготовка стенда.

Описанных сценариев: 94. Функциональных Maestro-кейсов: 129. Preview учитываются отдельно и не закрывают функциональные пробелы.

| Модуль | Сценариев | Maestro | Maestro + XCTest | Частично | Вручную / нужен стенд |
|---|---:|---:|---:|---:|---:|
| [ApplicationSplash](modules/ApplicationSplash/README.md) | 1 | 1 | 0 | 0 | 0 |
| [OnBoarding](modules/OnBoarding/README.md) | 3 | 3 | 0 | 0 | 0 |
| [WebDocument](modules/WebDocument/README.md) | 2 | 2 | 0 | 0 | 0 |
| [SelectUSExaminationType](modules/SelectUSExaminationType/README.md) | 2 | 2 | 0 | 0 | 0 |
| [Paywall](modules/Paywall/README.md) | 4 | 2 | 2 | 0 | 0 |
| [Scan](modules/Scan/README.md) | 8 | 6 | 2 | 0 | 0 |
| [Settings](modules/Settings/README.md) | 2 | 2 | 0 | 0 | 0 |
| [History](modules/History/README.md) | 4 | 4 | 0 | 0 | 0 |
| [ReportDetail](modules/ReportDetail/README.md) | 3 | 3 | 0 | 0 | 0 |
| [TemplateList](modules/TemplateList/README.md) | 2 | 2 | 0 | 0 | 0 |
| [TemplateAdd](modules/TemplateAdd/README.md) | 4 | 3 | 1 | 0 | 0 |
| [ReadyMadeTemplateList](modules/ReadyMadeTemplateList/README.md) | 2 | 2 | 0 | 0 | 0 |
| [TemplateEdit](modules/TemplateEdit/README.md) | 3 | 2 | 1 | 0 | 0 |
| [TemplateDelete](modules/TemplateDelete/README.md) | 2 | 2 | 0 | 0 | 0 |
| [UserSettings](modules/UserSettings/README.md) | 3 | 3 | 0 | 0 | 0 |
| [SettingsAI](modules/SettingsAI/README.md) | 5 | 2 | 3 | 0 | 0 |
| [SelectTranscriber](modules/SelectTranscriber/README.md) | 1 | 0 | 1 | 0 | 0 |
| [SelectTranscriptParser](modules/SelectTranscriptParser/README.md) | 2 | 1 | 1 | 0 | 0 |
| [SelectNeuralModel](modules/SelectNeuralModel/README.md) | 1 | 0 | 1 | 0 | 0 |
| [ManageSubscription](modules/ManageSubscription/README.md) | 4 | 3 | 1 | 0 | 0 |
| [SubscriptionRecovery](modules/SubscriptionRecovery/README.md) | 3 | 2 | 1 | 0 | 0 |
| [Storage](modules/Storage/README.md) | 3 | 3 | 0 | 0 | 0 |
| [StorageClearProtocols](modules/StorageClearProtocols/README.md) | 2 | 1 | 1 | 0 | 0 |
| [StorageClearAll](modules/StorageClearAll/README.md) | 2 | 1 | 1 | 0 | 0 |
| [About](modules/About/README.md) | 1 | 1 | 0 | 0 | 0 |
| [SelectDateOfBirth](modules/SelectDateOfBirth/README.md) | 1 | 0 | 1 | 0 | 0 |
| [SelectTemplate](modules/SelectTemplate/README.md) | 2 | 2 | 0 | 0 | 0 |
| [ImportMedia](modules/ImportMedia/README.md) | 1 | 1 | 0 | 0 | 0 |
| [Permission](modules/Permission/README.md) | 1 | 1 | 0 | 0 | 0 |
| [ScanCamera](modules/ScanCamera/README.md) | 2 | 0 | 2 | 0 | 0 |
| [PhotoLibraryPicker](modules/PhotoLibraryPicker/README.md) | 1 | 0 | 1 | 0 | 0 |
| [PhotoView](modules/PhotoView/README.md) | 3 | 1 | 2 | 0 | 0 |
| [PhotoRemark](modules/PhotoRemark/README.md) | 1 | 1 | 0 | 0 | 0 |
| [ScanSpeech](modules/ScanSpeech/README.md) | 4 | 1 | 3 | 0 | 0 |
| [ReportReceived](modules/ReportReceived/README.md) | 3 | 3 | 0 | 0 | 0 |
| [Share](modules/Share/README.md) | 2 | 2 | 0 | 0 | 0 |
| [RequestLimitExceeded](modules/RequestLimitExceeded/README.md) | 1 | 1 | 0 | 0 | 0 |
| [LegalUpdate](modules/LegalUpdate/README.md) | 2 | 2 | 0 | 0 | 0 |
| [NewVersion](modules/NewVersion/README.md) | 1 | 1 | 0 | 0 | 0 |

Полный список сценариев с причинами: [COVERAGE-GAPS.md](COVERAGE-GAPS.md).

## Публикация

Сценарии `manual` и `partial` остаются пробелами покрытия и не считаются пройденными. Они показаны в отчёте и названии коллекции Figma. Публикация разрешена только после успеха всех зарегистрированных исполняемых кейсов, проверки обязательных снимков и очистки окружения. Скриншоты Preview не заменяют отсутствующие функциональные проверки.

Для подключения сценария полностью реализуйте его шаги в Maestro/тестовом стенде, укажите точные flow IDs и только затем смените automation.kind на maestro. Не меняйте статус ради зелёного отчёта.
