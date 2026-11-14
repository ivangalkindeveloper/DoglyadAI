# Интеграция Робокассы в Doglyad

Серверный провайдер и браузерный checkout реализованы.
Официальный SDK Робокассы не используется: текущий
публичный iOS API требует пароли магазина в клиенте.

```text
Paywall: план + автопродление -> prepare_payment -> PostgreSQL + CreateInvoice
  -> Робокасса: email и оплата
  -> подписанный ResultURL -> проверка -> оплаченный период
Возврат в приложение -> check_payment -> точный UUID и planId -> статус
Продление -> worker -> новый InvoiceID + PreviousInvoiceID -> проверка
```

Основные файлы:

- `app/service/billing/robokassa_payment_provider.py`: подписи, Invoice API,
  OpStateExt, Recurring и Refund API.
- `app/service/billing/checkout_payment_service.py`: подготовка и проверка
  заказа с авторизацией владельца.
- `app/service/billing/subscription_service.py`: согласия, транзакции,
  оплаченные периоды, сверка и продления.
- `app/service/billing/payment_gateway.py`: ResultURL и HTTP-редирект в приложение без HTML.
- `ios/Doglyad/Repository/Subscription/SubscriptionRobokassaRepository.swift`:
  браузерная покупка и проверка серверного результата.
- `ios/Doglyad/Utility/Robokassa/RobokassaPaymentController.swift`:
  системная браузерная сессия с обработкой отмены.

Чеки регистрирует подключённый сервис «Робочеки СМЗ». Код не объявляет чек
доставленным по одному успешному платежу. Возврат денег не подразумевает
автоматическую корректировку НПД.

Проверка test/production различается: OpStateExt работает только в production.
HTTP 200, ответ Recurring `OK`, redirect и закрытие браузера не выдают доступ.
После неизвестного результата запрос списания/возврата не повторяется вслепую.

Разрешение на автопродление создаёт первая оплата через Робокассу.
Вся схема БД задана в единственной миграции `0001_initial`.

Реквизиты магазина, Recurring, чеки НПД, сквозная проверка и разрешённый Apple
сценарий остаются условиями выпуска. Реальные оплаты заблокированы по умолчанию.
[Настройка и API](BILLING.md), [проверка локально](BILLING_LOCAL.md),
[условия выпуска](BILLING_RELEASE_PLAN.md).
