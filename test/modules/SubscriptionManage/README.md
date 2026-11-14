# SubscriptionManage

Исходники: [ios/Doglyad/Application/Module/Subscription/SubscriptionManage](../../../ios/Doglyad/Application/Module/Subscription/SubscriptionManage).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `SubscriptionManage.tiers` | Нет подписки, Base и Pro | maestro |
| `SubscriptionManage.navigation` | Смена плана, ключ, поддержка и возврат | maestro |
| `SubscriptionManage.provider-actions` | Управление продлением и восстановление | manual |
| `SubscriptionManage.failure-cancel` | Ошибка загрузки и отмена задач | partial |
| `SubscriptionManage.recovery-copy` | Постоянный ключ восстановления | manual |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
