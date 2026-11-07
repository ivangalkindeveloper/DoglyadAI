# TemplateAdd

Исходники: [ios/Doglyad/Application/Module/Template/TemplateAdd](../../../ios/Doglyad/Application/Module/Template/TemplateAdd).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `TemplateAdd.create` | Создать и сохранить шаблон | maestro |
| `TemplateAdd.fields` | Тип, клавиатура и ограничения полей | mixed |
| `TemplateAdd.cancel-and-failure` | Отмена и ошибка сохранения | maestro |
| `TemplateAdd.ready-made` | Применить готовый шаблон в форме | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
