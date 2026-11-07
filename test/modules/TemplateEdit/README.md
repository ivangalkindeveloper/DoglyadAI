# TemplateEdit

Исходники: [ios/Doglyad/Application/Module/Template/TemplateEdit](../../../ios/Doglyad/Application/Module/Template/TemplateEdit).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `TemplateEdit.edit` | Изменение и сохранение шаблона | maestro |
| `TemplateEdit.fields-and-cancel` | Тип, фокус, границы и выход без сохранения | mixed |
| `TemplateEdit.failures` | Ошибки загрузки и сохранения | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
