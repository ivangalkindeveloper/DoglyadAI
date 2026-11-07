# ReportReceived

Исходники: [ios/Doglyad/Application/Module/Report/ReportReceived](../../../ios/Doglyad/Application/Module/Report/ReportReceived).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `ReportReceived.completed` | Получить и открыть готовый протокол | maestro |
| `ReportReceived.copy-email` | Копирование и рабочая почта | maestro |
| `ReportReceived.retry` | Ошибка, обрыв и повтор генерации | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
