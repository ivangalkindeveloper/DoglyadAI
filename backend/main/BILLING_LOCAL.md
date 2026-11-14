# Локальная проверка подписок

## Коротко

- `Backend: Local Mock` в VS Code запускает PostgreSQL в Docker, ожидает готовности и применяет миграции до старта API.
- `BILLING_DATABASE_URL` — строка подключения: адрес PostgreSQL, порт, имя БД, пользователь и пароль. Локальный профиль задает ее автоматически.
- Без URL backend работает без подписок. При заданном URL он проверяет доступность таблиц.
- Локальная БД доступна на `127.0.0.1:5433`. Данные лежат в Docker-томе `doglyad-local-billing-data` и сохраняются между запусками.
- В отдельном billing Compose данные PostgreSQL лежат в томе `billing_database`, внутри контейнера — `/var/lib/postgresql/data`.
- После подготовки БД примените миграции. Для оплаты запустите API и worker; для уведомлений нужен gateway с HTTPS.
- Миграции меняют структуру БД. Они не заменяют резервную копию и не восстанавливают удаленные платежи.

## Автоматическая подготовка локальной БД

Запустите Docker Desktop. Выберите профиль `Backend: Local Mock` в VS Code.
Его подготовка загружает обычное development-окружение, затем запускает
`tools/local_billing_database.py` через Make. Скрипт поднимает PostgreSQL 17,
ждет успешной проверки готовности и выполняет `alembic upgrade head`.
Ошибка подготовки останавливает запуск API. App Check остается обязательным.

БД можно подготовить отдельно из корня проекта:

```sh
make start-local-billing
make stop-local-billing
```

Остановка сохраняет контейнер и том. Автоматического удаления данных нет.

## Чистый локальный запуск

Останови локальный API, billing worker и payment ingress, если они запущены.
Выбери в VS Code `Backend: Local Mock (Cold)` или `Backend: Local Inference (Cold)`.
Эти профили стоят первыми в списке. Их подготовка удалит локальный
том `doglyad-local-billing-data`, создаст PostgreSQL заново и применит миграции.
Подписки, платежи, владельцы и остальные записи billing будут удалены при каждом
запуске Cold-профиля. Сброс отклоняется, если порт API `8000` занят или Docker
использует удалённый контекст.

Затем запусти iOS схемой `Doglyad-Debug-Local-Clean`. Перед обращением к backend
она удалит только запись `billing_identity` из Keychain локального приложения.
Клиент зарегистрирует нового анонимного владельца без подписки. Firebase App Check
сохранит свою настройку. Схема сбрасывает billing-идентификатор при каждом запуске;
для обычной работы используй `Doglyad-Debug-Local`.

Сброс можно выполнить отдельно из корня проекта:

```sh
make reset-local-billing
```

Обычные профили `Backend: Local Mock` и `Backend: Local Inference` сохраняют БД.
Development и Production не используют эту задачу. В iOS сброс разрешён только
для debug-сборки локального bundle ID в development-окружении с явным аргументом
`--reset-local-billing-identity`.
Локальная БД использует опубликованные тестовые реквизиты из
`docker-compose.local-billing.yml` и слушает только loopback-интерфейс.
Скрипт миграций всегда выбирает development и эту локальную БД.

Локальный URL:

```text
postgresql+asyncpg://doglyad_local:doglyad_local_only@127.0.0.1:5433/billing
```

Для ручного запуска API, worker и gateway передайте этот URL в их окружение.
Другие профили VS Code сохраняют свою прежнюю настройку подключения.

## Миграции

`migrations/env.py` берет подключение из `BILLING_DATABASE_URL` и загружает модели БД.
`alembic.ini` задает пути миграций и Python-импортов. `script.py.mako` служит шаблоном
для новых файлов в `versions/`. В каждом файле есть `upgrade()` и `downgrade()`.
Таблица `alembic_version` хранит текущую версию схемы.

Вся текущая схема задана одной начальной миграцией:

```text
Пустая БД -> 0001_initial -> текущая схема Apple/Робокассы
```

Команды ниже выполняются из `backend/main` с заранее загруженным окружением:

```sh
../../.venv311/bin/python -m alembic current
../../.venv311/bin/python -m alembic history
../../.venv311/bin/python -m alembic upgrade head
```

Для изменения структуры моделей создайте миграцию на отдельной БД разработки:

```sh
../../.venv311/bin/python -m alembic revision --autogenerate -m "Describe schema change"
```

Проверьте сгенерированные `upgrade()` и `downgrade()`, включая перенос существующих
данных. Выполните `make format-backend` из корня проекта. Проверьте миграцию на копии БД.
Перед обновлением рабочей БД сделайте резервную копию и остановите API, gateway и worker.
Примените `upgrade head`, затем запустите процессы новой версии. Billing Compose
выполняет миграцию отдельным процессом до запуска приложений.

После первого релиза не меняйте уже примененные миграции. Исправления оформляйте
следующей миграцией. Откат `0001_initial` разрешен только для пустой БД и удаляет
ее таблицы. При наличии данных он завершается ошибкой до удаления таблиц.

Проект ещё не выпущен, поэтому начальная миграция содержит актуальную схему
без переходов с прежних вариантов. Старую локальную БД без нужных данных
пересоздайте через `make reset-local-billing`. Сначала сохраните нужные данные.
Обычный локальный запуск не пересоздаёт БД. `stamp` меняет только метку Alembic
и не приводит старые таблицы к текущей схеме.

## Подробная настройка

Локальный main backend поддерживает подписки. Обычный запуск `Backend: Local Mock`
подменяет только генерацию ИИ: PostgreSQL и платежные провайдеры остаются настоящими.
Каталоги уже содержат восемь Apple-продуктов и восемь тарифов Робокассы. Для оплаты
все равно требуются локальная БД, миграции и настройки тестового магазина.

## Что подготовить

1. Локальную PostgreSQL через `make start-local-billing` либо собственный сервер
   PostgreSQL с отдельным `BILLING_DATABASE_URL`.
2. В `config/development/billing.json` уже настроены тарифы в общем списке `products`.
   Apple использует их ID, а Робокасса — также период и рублевую `price`. При необходимости
   для отдельного локального окружения можно использовать минимальный каталог:

   ```json
   {"termsVersion":"local-test-v1","tiers":[{"id":"pro","titleLocaleKey":"paywallProLabel",
      "featureLocaleKeys":["paywallProModelsDescription"]}],
    "products":[
     {"id":"local-pro-monthly","period":"monthly",
      "titleLocaleKey":"subscriptionProMonthlyLabel",
      "priceTemplateLocaleKey":"subscriptionMonthlyPriceDescription",
      "entitlement":"pro","price":{"amountMinor":10000,"currencyIso2Code":"RUB"}}
   ]}
   ```

   Поддерживаемые периоды Робокассы: `weekly`, `monthly`, `sixMonth`, `annual`.
   Текущие цены находятся в `config/development/billing.json`.
3. Магазин Робокассы и тестовые технические пароли:
   `ROBOKASSA_MERCHANT_LOGIN`, `ROBOKASSA_PASSWORD1`, `ROBOKASSA_PASSWORD2`.
   Задайте `ROBOKASSA_HASH_ALGORITHM=sha256` и такой же алгоритм в кабинете.
   В development используйте тестовую пару паролей; в production — боевую.
   `ENVIRONMENT` определяет `IsTest`; отдельного переключателя тестового режима нет.
   Оставьте `IS_ROBOKASSA_LIVE_ENABLED=false` до выполнения условий выпуска.
4. Обычные Firebase/SMTP настройки и `MODEL_SERVICE_TYPE=mock`, если GPU не нужен.
   App Check и авторизация владельца остаются обязательными.

## Запуск и callback

Секретные файлы настраивает владелец. `Variables` читает окружение процесса.
API и worker должны использовать один каталог и одни реквизиты магазина.

```sh
../../.venv311/bin/python -m alembic upgrade head
../../.venv311/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

В отдельных терминалах запустите worker и платёжный ingress:

```sh
../../.venv311/bin/python -m app.billing_worker
../../.venv311/bin/python -m uvicorn app.payment_main:app --host 127.0.0.1 --port 8001
```

Публичный HTTPS туннель должен вести на ingress. В кабинете Робокассы:

- ResultURL: `https://YOUR_TUNNEL_HOST/webhooks/robokassa`, метод POST.
- SuccessURL и FailURL: `https://YOUR_TUNNEL_HOST/payments/return`, метод GET.
- Алгоритм подписи должен совпадать с `ROBOKASSA_HASH_ALGORITHM`.

В приложении выбирается план. Подготовка создаёт заказ и счёт Робокассы; списания до оплаты нет.
Сервер сохраняет выбор автопродления из Paywall и создаёт счёт.
Браузер открывает страницу Робокассы; покупатель указывает email там.
Возврат в приложение выполняется по `doglyad://subscription/complete`.

В development успех подтверждает только подписанный ResultURL. `OpStateExt`
не поддерживает тестовые платежи; без доступного callback заказ останется pending.
Редирект SuccessURL не является доказательством оплаты. Не отправляйте поддельные
уведомления как замену проверке настоящего тестового магазина.

Реальная карточная форма, банковское подтверждение, возврат в приложение,
продления и доставка чеков требуют отдельной проверки с подключённым магазином.
Браузерные Maestro-сценарии требуют проверенных селекторов и тестового магазина.
Apple Sandbox и физический iPhone проверяются отдельно.

## База данных

`alembic upgrade head` создаёт текущую схему на пустой БД через `0001_initial`.
Для оплаты нужны счёт Робокассы и согласие покупателя. Режим Clean относится
только к отдельной локальной БД по правилам в начале документа.
