# Подписки Doglyad

Учёт владельцев, платежей, подписок и лимитов находится в PostgreSQL основного
backend. iOS использует StoreKit 2 для витрин вне RUS и Робокассу для RUS.
Фабрика читает текущую витрину при загрузке планов и новой покупке.
Apple-покупки обрабатываются и восстанавливаются независимо от текущей витрины.

## Оплата через Робокассу

1. Paywall показывает цену и переключатель «Автопродление», включённый по умолчанию.
2. `POST /v1/subscriptions/prepare_payment` принимает `planId`, показанную `price`
   и `isAutoRenewing`. Сервер сверяет цену с каталогом и сохраняет выбор, условия
   и снимок заказа до обращения к провайдеру.
3. Backend создаёт одноразовый счёт через `CreateInvoice` и возвращает ссылку
   непосредственно на Робокассу. Собственных HTML-форм, кодов и browser-cookie нет.
   `Recurring=true` передаётся только при включённом автопродлении.
4. Покупатель вводит email и оплачивает на странице Робокассы. ResultURL передаёт
   email в `EMail`; сервер сохраняет его как контакт для будущих продлений,
   а не как подтверждение личности или оплаты.
5. ResultURL проверяет подпись паролем №2, исходную строку суммы, счёт,
   магазин и окружение. Production дополнительно требует успешный `OpStateExt`
   (`Result.Code=0`, `State.Code=100`) и совпадение суммы.
6. Подписка и событие сохраняются транзакционно. Повторное уведомление не добавляет
   второй период. Автопродление и родительский счёт сохраняются согласно выбору
   пользователя; разовая покупка не создаёт расписание списаний.
7. `/payments/return` отвечает HTTP 303 на `doglyad://subscription/complete`.
   Этот технический маршрут не отдаёт HTML и не подтверждает оплату.

`SuccessURL`, `FailURL`, закрытие браузера и callback приложения не доказывают
оплату. В development `OpStateExt` недоступен: тестовый успех подтверждает только
ResultURL с тестовой подписью. Браузерный отказ без подтверждённого состояния
не превращается в оплаченный доступ.

Клиент использует статус из `prepare_payment` без повторной проверки перед
открытием браузера. После закрытия браузера репозиторий проверяет платёж один
раз; root не повторяет эту проверку сразу. При `pending` последующие запросы
читают только платёж. Общий статус подписки загружается после подтверждения.

## Ответственности

- `RobokassaPaymentProvider`: Invoice API, подписи, проверка состояния,
  Recurring и Refund API через общий `httpx.AsyncClient`. Ответы ограничены
  по размеру, запросы имеют общий срок и транспортные тайм-ауты.
- `CheckoutPaymentService`: подготовка и проверка заказа с обязательной
  авторизацией владельца. Запросить цену с клиента нельзя.
- `SubscriptionService`: транзакции, блокировки владельца, идемпотентное
  применение платежа, оплаченные периоды, лимиты, продления и возвраты.
- `PaymentGateway`: отдельный публичный ingress для браузера и проверенных
  уведомлений провайдеров. Он не отменяет App Check у клиентских API.
- `SubscriptionRobokassaRepository`: неизменяемые зависимости, открытие
  checkout и точная проверка результата. Состояние покупки принадлежит
  `SubscriptionRootViewModel`; фабрика не хранит снимок витрины.

## Владение и восстановление

`/register` создаёт UUID владельца и случайный bearer-секрет. Клиент хранит их
в Keychain; сервер хранит SHA-256 секрета. UUID не даёт доступ. Все клиентские
маршруты `/v1` требуют App Check; операции подписки дополнительно требуют
секрет владельца. Регистрация и экран входа пользователю не нужны.

Base и Pro платные. Без проверенного оплаченного периода генерация запрещена.
Сервер резервирует дневной лимит до генерации и возвращает его при ошибке.
Дни квоты считаются в UTC; worker освобождает зависшие резервы.

StoreKit восстанавливает Apple-покупки после проверки подписанных данных и
текущего состояния у Apple. Production и Sandbox разделены в реестре.
Для внешних подписок используется ключ восстановления. Его замена делает
предыдущий ключ недействительным; восстановление не создаёт новую оплату.
Предыдущая активная подписка не подтверждает другую ожидающую покупку.

## Продления и неизвестный результат

Собственный worker ведёт расписание. Параллельное расписание в кабинете
Робокассы включать нельзя. При первой карточной оплате сохраняется родительский
номер счёта. Для продления создаётся новый номер и `PreviousInvoiceID`.
Подключение Recurring требует согласования с Робокассой.

Перед сетевым запросом сохраняется факт отправки и снимок родительского счёта.
После тайм-аута повторный вызов сверяет прежний счёт; повторная команда списания
не отправляется. Потерянная ссылка первого счёта восстанавливается через
`GetInvoiceInformation`. Неразрешённый результат переводится в `needsReview`.
Отмена продления сохраняет оплаченный срок и не отменяет сверку уже отправленной
операции. Новая покупка заменяет только неотправленные истёкшие продления.

## Возвраты и чеки НПД

`request_refund(payment_id, amount_minor, operation_id)` предназначен для
доверенного служебного вызова. Произвольного публичного API возврата нет.
Он сохраняет локальную заявку до `Refund/Create`, затем сохраняет полученный
`requestId`. Worker проверяет известные заявки через `Refund/GetState`.
Повтор с тем же локальным ID не отправляет второй возврат. Полный подтверждённый
возврат отзывает соответствующий период; частичный учитывается отдельно.

При потере ответа Refund/Create неизвестный `requestId` требует ручной сверки:
у API не описаны ключ идемпотентности и поиск такой заявки. Возвраты, созданные
только в кабинете, также нужно связать с локальным реестром. Нельзя придумывать
поддержку получения полного списка возвратов.

«Робочеки СМЗ» после активации регистрируют доход и доставляют чек НПД покупателю.
Для ИП на НПД требуется заявка в поддержку. Интеграция передаёт email и название
подписки; повторный чек в «Моём налоге» создавать не нужно. Реальную доставку,
ссылку/статус чека и корректировку при полном/частичном возврате нужно подтвердить
с магазином. `is_receipt_pending` не является доказательством доставки чека.

## Настройки

Секретное окружение задаёт владелец; код и документация не содержат реквизитов:

```dotenv
BILLING_DATABASE_URL=postgresql+asyncpg://...
ROBOKASSA_MERCHANT_LOGIN=...
ROBOKASSA_PASSWORD1=...
ROBOKASSA_PASSWORD2=...
ROBOKASSA_PASSWORD3=...
ROBOKASSA_HASH_ALGORITHM=sha256
IS_ROBOKASSA_LIVE_ENABLED=false
```

`ENVIRONMENT=development` принудительно использует `IsTest=1` и тестовые пароли.
Production использует боевые пароли. Выбранный алгоритм должен совпадать с
техническими настройками магазина. Пароль №3 нужен для возвратов.

Кабинет Робокассы:

- ResultURL: `https://PAYMENT_HOST/webhooks/robokassa`, POST.
- SuccessURL и FailURL: `https://PAYMENT_HOST/payments/return`, GET.

Источники подписок — `apple` и `robokassa`. Миграция `0001_initial` сразу
создаёт текущую схему: счета Робокассы, параметры магазина, согласия,
контакты для чеков и возвраты. Применение к пустой БД: `alembic upgrade head`.
Проект ещё не выпущен; совместимость с прежними схемами не поддерживается.

## Выпуск и проверка

`IS_ROBOKASSA_LIVE_ENABLED=false` остаётся обязательным до подтверждения магазина,
Recurring, чеков НПД и требований Apple. Текущий браузерный адаптер сам по себе
не реализует `ExternalPurchaseLink` и отчётность внешних покупок Apple.
До выпуска в российском App Store нужны применимые entitlement, разрешённый
переход по ссылке и передача внешних покупок. StoreKit для остальных витрин
сохраняется. Подробный список: [BILLING_RELEASE_PLAN.md](BILLING_RELEASE_PLAN.md).

Локальный запуск: [BILLING_LOCAL.md](BILLING_LOCAL.md).
Развёртывание и восстановление БД: [deploy/billing](../../deploy/billing/README.md).
Модульные тесты проверяют реестр, подписанные уведомления, отсутствие списания
до согласия, подписи API, состояние test/production и неизвестный результат.
Сборка и эти проверки не заменяют E2E с подключённым магазином и физическим iPhone.

Документация: [Invoice API](https://docs.robokassa.ru/ru/invoice-api),
[ResultURL](https://docs.robokassa.ru/ru/notifications-and-redirects),
[OpStateExt](https://docs.robokassa.ru/ru/xml-interfaces),
[Recurring](https://docs.robokassa.ru/ru/recurring-payments),
[Refund API](https://docs.robokassa.ru/ru/refund-api),
[Робочеки СМЗ](https://robokassa.com/online-check/robocheck-smz/).

## Recovery and plan changes

Successful authenticated payment/status responses include a permanent owner recovery key.
The server stores its hash and an owner-bound encrypted copy. The encryption key is
derived with a billing-specific HMAC purpose from the report-storage encryption key.
The client saves the recovery key in Keychain and copies it from subscription management.
Copying does not rotate it. Recovery returns the identity and current subscription in one request.

Robokassa plan changes charge the full catalog price and start a new full period
immediately after verified payment. The new subscription replaces previous Robokassa
access and disables every previous renewal schedule; unused time is not carried over.
Replaced subscriptions cannot become active again after expiration or late callbacks.
The auto_renewal endpoint only disables renewal. Re-enabling is rejected even when
an earlier parent invoice exists; the user can enable renewal only with a new purchase.
Closing the browser reconciles and deactivates an
unpaid unused invoice before allowing a replacement. Bank-processing outcomes retain
the invoice identity and continue server reconciliation, including needsReview rows.
