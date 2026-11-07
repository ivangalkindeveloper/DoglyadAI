# Storage

Исходники: [ios/Doglyad/Application/Module/Storage/Storage](../../../ios/Doglyad/Application/Module/Storage/Storage).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `Storage.summary` | Переходы и отмена очистки | maestro |
| `Storage.speech-model` | Удаление speech-модели | maestro |
| `Storage.failure-lifecycle` | Ошибка очистки и уход с экрана | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
