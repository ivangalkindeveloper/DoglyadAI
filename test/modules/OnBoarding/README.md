# OnBoarding

Исходники: [ios/Doglyad/Application/Module/OnBoarding](../../../ios/Doglyad/Application/Module/OnBoarding).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `OnBoarding.first-launch` | Первый запуск и завершение onboarding | maestro |
| `OnBoarding.legal-links` | Документы до согласия | maestro |
| `OnBoarding.completion-failure` | Ошибка сохранения onboarding | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
