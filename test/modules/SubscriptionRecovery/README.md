# SubscriptionRecovery

Исходники: [ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery](../../../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `SubscriptionRecovery.create-copy` | Создание и копирование ключа | maestro |
| `SubscriptionRecovery.restore` | Восстановление на другом клиенте | maestro |
| `SubscriptionRecovery.failure-back` | Ошибка сети и выход | mixed |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
