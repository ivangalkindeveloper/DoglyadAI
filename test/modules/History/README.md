# History

Исходники: [ios/Doglyad/Application/Module/History](../../../ios/Doglyad/Application/Module/History).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `History.empty` | Пустая история | maestro |
| `History.pages` | Заполненная история и подгрузка | maestro |
| `History.open-report` | Открытие готового и текущего протокола | maestro |
| `History.load-failure` | Ошибки первой и следующей страницы | mixed |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
