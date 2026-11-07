# ManageSubscription

Исходники: [ios/Doglyad/Application/Module/Subscription/ManageSubscription](../../../ios/Doglyad/Application/Module/Subscription/ManageSubscription).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `ManageSubscription.tiers` | Нет подписки, Base и Pro | maestro |
| `ManageSubscription.navigation` | Смена плана, ключ, поддержка и возврат | maestro |
| `ManageSubscription.provider-actions` | Управление продлением и восстановление | maestro |
| `ManageSubscription.failure-cancel` | Ошибка загрузки и отмена задач | mixed |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
