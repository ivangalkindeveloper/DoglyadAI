# Paywall

Исходники: [ios/Doglyad/Application/Module/Subscription/Paywall](../../../ios/Doglyad/Application/Module/Subscription/Paywall).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `Paywall.catalog` | Тарифы, периоды и выбор | maestro |
| `Paywall.purchase` | Успешная покупка выбранного плана | maestro |
| `Paywall.pending-cancel` | Ожидание, отмена и проверка платежа | mixed |
| `Paywall.errors-restore-documents` | Загрузка, ошибка покупки, восстановление и документы | mixed |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
