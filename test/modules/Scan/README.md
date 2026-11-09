# Scan

Исходники: [ios/Doglyad/Application/Module/Scan/Scan](../../../ios/Doglyad/Application/Module/Scan/Scan).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `Scan.patient-consent` | Проверить согласие до запуска генерации | mixed |
| `Scan.draft` | Поля пациента, клавиатура и черновик | mixed |
| `Scan.validation` | Границы и обязательные данные | mixed |
| `Scan.template-model` | Шаблон, модель и параметры генерации | maestro |
| `Scan.media` | Импорт, просмотр и удаление фото | maestro |
| `Scan.speech-gating` | Голосовой ввод по подписке | maestro |
| `Scan.clear` | Очистить черновик | maestro |
| `Scan.errors` | Ошибки загрузки, черновика и генерации | mixed |
| `Scan.settings-dev` | Переход в настройки и DEV-заполнение | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
