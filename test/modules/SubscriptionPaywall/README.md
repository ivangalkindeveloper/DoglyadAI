# SubscriptionPaywall

Исходники: [ios/Doglyad/Application/Module/Subscription/SubscriptionPaywall](../../../ios/Doglyad/Application/Module/Subscription/SubscriptionPaywall).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `SubscriptionPaywall.catalog` | Тарифы, периоды и выбор | mixed |
| `SubscriptionPaywall.purchase` | Успешная покупка выбранного плана | manual |
| `SubscriptionPaywall.pending-cancel` | Ожидание, отмена и проверка платежа | manual |
| `SubscriptionPaywall.errors-restore-documents` | Загрузка, ошибка покупки, восстановление и документы | partial |
| `SubscriptionPaywall.return-navigation` | Возврат после оплаты и восстановления | mixed |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
