# PhotoView

Исходники: [ios/Doglyad/Application/Module/PhotoView](../../../ios/Doglyad/Application/Module/PhotoView).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `PhotoView.navigation-zoom` | Выбор фото и масштабирование | mixed |
| `PhotoView.delete` | Удаление среднего и последнего фото | maestro |
| `PhotoView.remarks` | Точки замечаний и сохранение видимости | mixed |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
