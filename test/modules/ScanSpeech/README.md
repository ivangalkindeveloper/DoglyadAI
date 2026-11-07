# ScanSpeech

Исходники: [ios/Doglyad/Application/Module/Scan/ScanSpeech](../../../ios/Doglyad/Application/Module/Scan/ScanSpeech).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `ScanSpeech.record` | Подготовка, запись и остановка | mixed |
| `ScanSpeech.review` | Исправить транскрипт и выбрать поля | mixed |
| `ScanSpeech.cancel-rerecord` | Перезапись и отмена | mixed |
| `ScanSpeech.failures` | Ошибка подготовки модели и парсинга | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
