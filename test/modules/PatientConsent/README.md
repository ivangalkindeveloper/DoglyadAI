# PatientConsent

Исходники: [ios/Doglyad/Application/Module/PatientConsent](../../../ios/Doglyad/Application/Module/PatientConsent).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `PatientConsent.confirmation` | Подтверждение согласия до генерации | mixed |
| `PatientConsent.failure-cancel` | Ошибка записи и закрытие во время подтверждения | mixed |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
