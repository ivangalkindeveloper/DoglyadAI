# Subscriptions

## Коротко: текущая реализация

Учет подписок, платежей и лимитов запросов ведет PostgreSQL в `backend/main`.
Клиент получает с сервера тариф и оплаченный срок. RevenueCat удален.
Сейчас реализован iOS. Android остается следующим этапом.

```text
App Store storefront НЕ RUS:
iOS -> StoreKit 2 -> Apple (оплата)
iOS -> backend/main -> проверка подписи и статуса у Apple
                   -> PostgreSQL -> доступ в iOS

App Store storefront RUS:
iOS -> SDK ЮКассы -> платежный токен -> backend/main -> ЮКасса (оплата)
backend/main -> проверка платежа у ЮКассы -> PostgreSQL -> доступ в iOS

Apple / ЮКасса -> платежный gateway -> проверка уведомления -> PostgreSQL
worker -> сверка платежей, продления ЮКассы, обновление статуса -> PostgreSQL
```

Ветка новой покупки определяется по региону App Store, а не по IP или языку.
Цены Apple приходят из StoreKit. Цены ЮКассы приходят из `billing.json`.
Без экрана входа владельца определяют UUID и случайный секрет в Keychain.
Apple-покупку восстанавливает StoreKit. Для ЮКассы нужен ключ восстановления.

Нативная форма SDK ЮКассы уже реализована. Она не является сценарием
`ExternalPurchaseLink`. Возможность ее выпуска в App Store не подтверждена.
Реальные платежи нельзя включать до выполнения условий раздела
[Outstanding launch requirements](#outstanding-launch-requirements).

Локальный backend подключается к БД по `BILLING_DATABASE_URL`. Профиль VS Code
`Backend: Local Mock` сначала запускает PostgreSQL в Docker и применяет миграции.
Сам процесс API схему БД не меняет. Подробности и команды:
[BILLING_LOCAL.md](BILLING_LOCAL.md). Контур резервных копий в Object Storage
подготовлен отдельно и требует настройки: [deploy/billing](../../deploy/billing/README.md).

## Detailed implementation

Billing belongs to `backend/main`, using PostgreSQL, an independent worker and a
separate browser/provider ingress. There is no user profile or login screen.
RevenueCat is no longer a dependency. Android is a subsequent project phase.

## Ownership and access

- `/v1/subscriptions/register` creates an anonymous owner UUID and a random device
  secret. The iOS client persists them in Keychain (`ThisDeviceOnly`). The database
  stores the SHA-256 hash of the secret. UUID alone grants no access.
- Client billing and generation requests require both Firebase App Check and the
  device bearer secret. Configuration remains protected by App Check as before.
- Both **Base and Pro are paid**. Without a current verified subscription, status
  is `null`; generation and paid features are denied. The plan's `entitlement`
  selects limits from `application.json`. Overlapping plans use the higher tier.
- The server reserves a daily quota slot before generation, commits it on success
  and returns it on failure. The server creates each usage ID; the client sends
  no quota operation ID. Each generation request is metered independently.
  The client refreshes the server status after a generation attempt, independently
  of local report persistence. Retrying a local save does not generate another report.
  The worker releases reservations left pending for ten minutes by a crashed process.
  Quota days are UTC. Local settings, examination catalogs and templates stay in
  configuration files; only transactional billing/usage data needs PostgreSQL.
- Signing in is unnecessary, but anonymous identity is not a durable proof of a
  real person. Creating a new identity cannot be fully prevented without a login.
  It does not grant paid access. App Check is application attestation, not user auth.

## Purchase and restoration

The iOS provider repositories are immutable. `SubscriptionRepositoryFactory`
selects `SubscriptionYooKassaRepository` for the confirmed `RUS` storefront and
`SubscriptionStoreKitRepository` otherwise; an unknown storefront keeps native
StoreKit as the default. The factory reads the current storefront on each plan
request or new purchase and rejects plans from a different provider. There is no
storefront observer, startup storefront snapshot or selected provider in the
dependency container. `PaywallViewModel` fetches and owns its plans
directly through the factory. `SubscriptionRootViewModel` owns the shared status,
pending payment ID and transaction/purchase tasks. Provider operations use shared
HTTP/Keychain access in `SubscriptionBackendRepository`. `Paywall` and
`ManageSubscription` receive root state/action closures, not root instances or
plan-loading closures. Settings opens `ManageSubscription` directly. Its change-plan
action pushes `Paywall`. Management shows the current plan, paid-through date,
server-supplied tier benefits and renewal status. Provider management, StoreKit
restoration, refunds and support remain available there. Recovery key creation,
copying and entry live in the separate `SubscriptionRecovery` screen. These
modules receive root operations through closures; keys retain their original case.
The native `Paywall*` module defaults to Pro and the longest available period
(annual in the current catalog). Tier/plan selection is local; only Continue
starts a purchase. The header scrolls with the content and stretches only during
downward overscroll. The purchase button uses `DScreen.bottom`; scroll content
includes `bottomInset`. All paywall text comes from server `paywall*` keys.
Debug Canvas previews read translations and tariffs from backend development JSON
files through preview factories. They do not call payment providers or bundle
copies of server catalogs.
Each YooKassa purchase creates its own SDK adapter; the adapter holds only UI
continuations and callback guards, while payment IDs and canonical checks stay
outside the SDK. It does not retain HTTP transport or a subscription snapshot.

Existing subscriptions are managed by their backend `source`, independently of
the storefront used for a new purchase. StoreKit updates and startup reconciliation
also run for a Russian storefront, so previous Apple purchases remain deliverable.
Explicit Restore processes Apple entitlements and unfinished transactions. Apple
prices and subscription periods come from StoreKit; the backend catalog supplies
product IDs and tier mappings. `/v1/subscriptions/plans` returns one `products`
array with shared IDs, tiers, periods and a nested RUB `price` for YooKassa.
Products declare `titleLocaleKey` and `priceTemplateLocaleKey` in `billing.json`.
The backend resolves them through the requested language's `l10n.json` and
returns `title` and `priceTemplate`. Clients substitute the provider's display
price into the single `{price}` placeholder; paywall view models do not select keys.
`tiers` declares each tier's `titleLocaleKey` and `featureLocaleKeys`. The same
response returns localized `id`, `title` and `features` in its `tiers` array.
The paywall renders these labels and benefits without client-side key mappings.
Loaded immutable states retain the catalog and selection through purchasing,
pending and operation failures. A first-load failure has its own state without
an empty placeholder catalog.
The Apple repository obtains prices and periods from StoreKit. The application
does not retain a product cache.

Pending purchases retain their selected product and provider reference in the root
view model. YooKassa completion requires a canonical response with the exact payment
ID and `planId`, followed by a server access refresh. Current access can belong
to another active product; it never replaces confirmation of the selected payment.
StoreKit snapshots the latest
verified transaction before purchase; pending completion requires a newer verified
transaction for the selected product. Paywall checks this result before closing.
An unrelated active subscription cannot complete a pending purchase.

**StoreKit 2:** the current App Store storefront chooses the route. Non-Russian
storefronts load runtime Apple products and localized prices. Purchases carry the
owner UUID as `appAccountToken`. The backend verifies Apple-signed JWS with trusted
Apple roots and fetches the current subscription through App Store Server API.
Only then does the client finish the transaction. Unfinished transactions are
retried by `Transaction.updates` and explicit Restore. App Store Server Notifications
V2 and six-hour worker reconciliation update expiration, grace periods and revocation.
Sandbox entitlements require explicit `IS_APPLE_SANDBOX_ALLOWED=true`.

**Russian storefront (`RUS`):** the iOS client uses the official YooKassa iOS SDK
12.0.2 through Swift Package Manager. `YooKassaPaymentController` presents the
vendor's card/SBP payment UI and confirmation, while StoreKit 2 handles other
storefronts. Native YooKassa payment is a user-approved implementation choice; it
is not an Apple External Purchase Link flow or evidence of App Store permission.

`POST /v1/subscriptions/prepare_payment` reserves an owner-bound order and returns
its immutable amount, tier description, terms version and the public SDK client
key. The SDK returns a one-time token; `/tokenize_payment` submits it to YooKassa
using the persisted order's idempotency key. Only the token hash and consent are
stored. `/check_payment` verifies the canonical provider result; SDK success,
3DS completion or a bank callback cannot grant access by themselves. Reopening an
in-flight order uses its original ID; a missing/uncertain token is never replaced
by a worker-generated redirect charge. The worker reconciles known provider IDs.

A new purchase replaces an expired YooKassa subscription: while holding the owner
lock, it stops the old automatic renewal and cancels only renewal orders that
have never been submitted. A submitted/unknown renewal blocks another purchase
until its outcome is reconciled. Abandoning the new checkout does not restart
the replaced old subscription's automatic renewal.

The SDK's `customerId` is omitted: anonymous owners do not get a saved-card picker.
Recurring method IDs remain on the server. `doglyad://` callbacks are forwarded to
`YooKassa.handleOpen`. SDK logging is disabled. There is no browser page or copied
code in the native iOS purchase flow. The separate gateway retains its independently
supported `/pay` browser flow and provider callbacks.

The provider chooses from payment methods enabled for the merchant (cards and SBP
must be enabled there). `save_payment_method=true` requests recurring authorization.
Only a successful canonical payment with `payment_method.saved=true` enables renewal.
SBP recurring payments depend on the payer's bank support; test merchants do not
prove live SBP availability. Unsupported saving leaves a single paid period.

The return page never grants access. Webhooks trigger a server-to-server fetch;
merchant ID, environment, amount, currency and order are checked. Provider payment
IDs and ledger events make repeated notifications idempotent. Before the provider
request, a separate committed transaction stores `submitted_at` and the renewal's
saved payment-method ID. Retries use the same order ID, amount and method snapshot.
Cancellation stops future renewals; it does not discard an already submitted
payment. A timeout/crash leaves a reconcilable order. An initial definitive HTTP
400 rejection, or a failed merchant preflight before submission, closes the order
so a new purchase can use a fresh token. A rejection following an earlier unknown
attempt does not erase that uncertainty.

The worker does not blindly replay an unknown charge after 23 hours from its first
submission (`needsReview` requires investigation). It also revisits completed
payments in bounded batches, oldest reconciliation attempt first, so one failing
provider object cannot monopolize that queue. It fetches the canonical payment
and all pages of refunds. Refund pagination has one provider-operation deadline.
This recovers missed refund notifications within provider API retention limits.

`billing_payments.refunded_amount_minor` stores the confirmed total, independently
of access. `billing_refunds` stores each provider refund ID, amount, currency,
status and timestamps. Repeated pages/notifications update the same row. Confirmed
totals and terminal refund states cannot regress after a stale read. Full refunds
adjust access and stop renewal; partial refunds retain access and remain in the
money ledger. Canceling a subscription keeps its already-paid period.

**Restore:** Apple uses the explicit Restore button (`AppStore.sync`) and a verified
existing original transaction. A valid active purchase can reissue a device secret
for its original billing owner. External purchases use the recovery key generated
in Subscription → Support; copy it before losing access to the device. The server
stores only its hash; generating a new key invalidates the old key. Restoring adds
a credential, so another working device remains connected. If Keychain and the
recovery key are both lost, external purchases need manual support and proof of
payment; UUID, IP address or a redirect cannot restore ownership.

## Configuration and test setup

See [local subscription testing](BILLING_LOCAL.md) for prerequisites, process commands,
storefront selection and the distinction between SDK mocks and a test-merchant payment.

1. Run PostgreSQL and set a secret `BILLING_DATABASE_URL` using the
   `postgresql+asyncpg://...` driver. Run `alembic -c backend/main/alembic.ini upgrade head`
   from the repository root with `ENVIRONMENT` set. Migrations are explicit, not
   automatic table creation at application startup. `Dockerfile` includes Alembic
   and the migration snapshot.
2. Each environment's server-only `billing.json` contains one product catalog:

   ```json
   {"termsVersion":"YOUR_PUBLISHED_TERMS_VERSION",
    "tiers":[{"id":"pro","titleLocaleKey":"paywallProLabel",
      "featureLocaleKeys":["paywallProModelsDescription"]}],
    "products":[
      {"id":"YOUR_SHARED_PRODUCT_ID","period":"monthly","entitlement":"pro",
       "titleLocaleKey":"subscriptionProMonthlyLabel",
       "priceTemplateLocaleKey":"subscriptionMonthlyPriceDescription",
       "price":{"amountMinor":10000,"currencyIso2Code":"RUB"}}
    ]}
   ```

   The example price is not a release recommendation. YooKassa supports `weekly`,
   `monthly`, `sixMonth` and `annual`: seven days or one/six/twelve calendar months.
   IDs must be unique. Every listed entry is available for a
   new purchase; removing it stops offering it. Existing YooKassa orders/subscriptions
   retain their snapshots. A previously recorded Apple product retains its stored
   tier for verified restoration/reconciliation; an unknown retired product or an
   unrecognized product change cannot grant access. Apple prices and periods are
   not copied into this configuration. Existing YooKassa orders and subscriptions snapshot
   price, currency, tier and both month/day intervals; change prices using new plan
   IDs after release. The initial schema includes both day and calendar-month intervals.
3. Set `BILLING_PUBLIC_URL=https://YOUR_DOMAIN/pay`, `YOOKASSA_SHOP_ID`,
   `YOOKASSA_SECRET_KEY`, `YOOKASSA_CLIENT_APPLICATION_KEY`. Enable mobile SDK/token
   payments with the merchant manager and obtain the public client key.
   `ENVIRONMENT=development` accepts only test shops and test payments;
   `ENVIRONMENT=production` accepts only live shops and live payments.
   Before every new charge the provider's `/me` settings must match this mode.
   Canonical payment verification enforces the same mode, including callbacks.
   Keep the temporary launch gate `IS_YOOKASSA_LIVE_ENABLED=false` until all launch
   requirements below are met; production alone does not enable real charges.
   Test credentials belong in `secrets/.env.development`, live credentials in
   `secrets/.env.production`. Remove the obsolete `IS_YOOKASSA_TEST_ALLOWED` setting.
4. Apple requires `APPLE_BUNDLE_ID`, numeric `APPLE_APP_ID`, `APPLE_ISSUER_ID`,
   `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_PATH`, `APPLE_ROOT_CERTIFICATES_PATH` (trusted
   Apple `.cer` root certificates obtained independently, never request-supplied).
   Mount secrets read-only. No Apple signing capability has been fabricated or added.
5. Run three entry points against the same database: `app.main:app`,
   `app.payment_main:app`, and `python -m app.billing_worker`. HTTP applications retain
   unconditional Firebase startup verification. The independent `BillingWorker`
   creates only its HTTP client, `BillingDatabase` and billing services; no FastAPI
   app, Firebase initializer, model service or SMTP service is constructed there.
   Register callbacks at
   `/webhooks/yookassa` and `/webhooks/apple`. Do not expose the database or internal
   ASGI ports publicly. See [deployment and backups](../../deploy/billing/README.md).
6. The iOS SDK is linked as `YooKassaPaymentsBinary` from the official YooMoney
   package, pinned to 12.0.2. Public SDK parameters come from the protected backend;
   merchant secret keys never enter the app. The obsolete `REVENUECAT_API_KEY`
   is removed from Local/Development/Production `.xcconfig` files. No YooKassa
   key is added there: `/prepare_payment` supplies `clientApplicationKey` from the
   backend's `YOOKASSA_CLIENT_APPLICATION_KEY`. Validate cards/3DS and bank-app SBP return on a physical device.
   ATS remains restricted; no global TLS/HTTP bypass was enabled. For banks using
   Russian national CA certificates, the vendor requires user-installed system
   trust or `NSAllowsArbitraryLoadsInWebContent` with SDK-managed pinning. Neither
   has been validated on a device here; compatibility with these 3DS pages remains
   unresolved. See the official package README's certificate section.

The backend pins the official
[Python SDK](https://git.yoomoney.ru/projects/SDK/repos/yookassa-sdk-python/browse/README.md)
as `yookassa==3.13.0`. `YooKassaPaymentProvider` retains the merchant/test/live checks
and delegates to `YooKassaSDKAdapter`. SDK `PaymentRequest`/`RefundRequest` objects
validate and serialize payloads; its `ApiClient` builds authentication headers and
maps API errors. Responses retain the original JSON types for canonical ledger
verification rather than using coerced SDK response models.

The SDK's default transport is synchronous and its `Configuration.timeout` is a
retry backoff, not an HTTP deadline. `YooKassaSDKClient` therefore overrides the
transport with the lifespan-owned `httpx.AsyncClient`. Synchronous SDK processing
runs in `asyncio.to_thread`; HTTP execution remains on the owning event loop.
At most four SDK calls run concurrently per adapter, leaving default executor
capacity for DNS resolution and other application work. One absolute operation
deadline includes both capacity/executor queue time, and cancellation
prevents queued requests from being sent later and cancels in-flight transport.
Connect/read/write/pool timeouts remain in `server.json`.

Each call has isolated credentials: global SDK `Configuration` is never modified.
SDK raw-body/header logging and automatic retries are not used. Every mutation
requires the persisted order/refund idempotency key; no replacement key is generated.
The adapter currently supports merchant settings, payments and refunds. Receipt
integration, the subscription ledger, renewal worker, owner authentication and
canonical provider verification remain separate responsibilities.

When no database URL is configured, billing operations fail explicitly with 503;
there is no production bypass or fallback that grants subscription access.

### Initial catalog and conversion

Both environments contain Base/Pro weekly, monthly, six-month and annual products.
YooKassa tariffs expose their duration as `period`; Apple periods come from StoreKit.
The client sees only `apple` or `yookassa` as the subscription source. The ledger
stores Apple's verified `Production`/`Sandbox` environment separately in
`apple_environment`, and reconciliation uses that field. The initial migration
creates the environment check and separate Apple/YooKassa transaction indexes.
Apple identifiers were taken from the developer's RevenueCat sample export:
`base_weekly`, `base_monthly`, `base_six_months`, `base_annual` and their `pro_`
counterparts. The App Store Connect six-month duration is authoritative; the
export incorrectly describes those products as `P1M`. No exported group IDs or
placeholder Apple prices were imported into the Apple registry.

The private `secrets/ pricing/subscription_pricing_calculator.py` calculates USD prices,
fetches the [Bank of Russia XML rate](https://www.cbr.ru/development/SXML/)
for the current date and converts all eight products to RUB with Decimal.
USD and RUB prices use whole currency units. Each price rounds to the nearest
configured step minus one unit. RUB uses a 100-ruble step: 804.58 becomes 799,
1609.96 becomes 1599. Ties round upward. An exact x99 price remains unchanged.
USD uses the configured weekly/monthly/six-month/annual steps of 1/10/1/100 dollars.
The calculator checks break-even again after rounding. Discounts are targets
before rounding, not exact final savings. `amountMinor` stores integer kopeks.
The calculator includes YooKassa's configured 3.5% fee, removes RevenueCat's fee
and uses the larger Apple/YooKassa channel fee for its break-even calculation.
Any Apple external-purchase commission needs separate accounting before launch.

The catalogs were updated on 2026-10-27 using the rate effective 2026-10-27:
**1 USD = 80.4909 RUB**. These whole-USD calculations replace the previous
fractional-USD calculation. Actual App Store prices require a separate change
in App Store Connect; the script only writes backend YooKassa amounts.

| Period | Base USD | Base YooKassa RUB | Pro USD | Pro YooKassa RUB |
|---|---:|---:|---:|---:|
| Week | 3 | 199 | 5 | 399 |
| Month | 9 | 699 | 19 | 1499 |
| Six months | 51 | 4099 | 108 | 8699 |
| Year | 99 | 7999 | 199 | 15999 |

Every successful run writes a Markdown table next to the private calculator:
`secrets/ pricing/subscription_pricing_calculator.md`. Run without arguments to calculate
prices and refresh that report. Add
`--update-billing` to explicitly update YooKassa amounts in both catalogs.
A rate-fetch/validation failure stops the calculation before any catalog write.
Backend processes do not call the calculator or reprice subscriptions at runtime.
Existing orders and renewals retain their stored price snapshots.
Apple prices continue to come from StoreKit at runtime. No merchant credentials
or live-payment flags were changed. Product availability in the catalog does not
enable live charges.

## Outstanding launch requirements

This is an implementation for sandbox validation, not an activated merchant rollout.
Do **not** enable live recurring charges before all items below are completed:

- Confirm foreign developer/entity eligibility and obtain Apple's Russian external
  purchase permissions applicable to the chosen native SDK flow; an external-link
  entitlement alone does not authorize an embedded form. For an approved Apple
  external-purchase program, implement External Purchase Server API
  reporting, including unused tokens, transactions, renewals and refunds. The present
  code only retains a checkout's attribution token; it does **not** submit those reports.
- Settle receipts for the actual tax status. YooKassa ended its self-employed receipt
  service on 2025-12-29. `is_receipt_pending` tracks unresolved receipts; it is **not**
  automatic integration with My Tax. Receipt creation/delivery, buyer contact handling
  and renewal notices need an approved implementation before a live launch.
- Update and review the published RU/EN terms/privacy text (still describing the
  previous payment flow), merchant offer, cancellation/refund contacts and tax details.
- Test Apple Sandbox plus a YooKassa test merchant end to end on a device; test live
  SBP separately after merchant activation. Repeat PostgreSQL checks in the deployment environment and test provider
  ambiguity, worker restart and refunds against sandbox services.
- Enable deployment/monitoring, complete an isolated backup restoration, and record
  measured RPO/RTO. Existing fleet rollout scripts do not yet install the optional
  billing overlay or its host timers automatically.

Official references: [Apple external purchase APIs](https://developer.apple.com/documentation/storekit/external-purchase),
[Apple external tokens](https://developer.apple.com/documentation/storekit/receiving-and-decoding-external-purchase-tokens),
[YooKassa API](https://yookassa.ru/developers/api),
[SBP](https://yookassa.ru/developers/payment-acceptance/integration-scenarios/manual-integration/other/sbp),
[YooKassa changelog](https://yookassa.ru/developers/using-api/changelog).

## Verification

The local implementation was checked with main-backend Ruff/mypy and 478 tests
(three PostgreSQL-only checks skipped in the default run), plus 34 billing checks
against an isolated PostgreSQL 17 container. The latter
include parallel SDK preparation/tokenization, 16 parallel quota reservations,
parallel checkout attempts and 16 duplicate provider notifications. Alembic upgrade
and metadata comparison passed on PostgreSQL.
The consolidated initial migration is checked against ORM metadata. Tests cover
provider/environment uniqueness, persisted defaults, repeated upgrades and empty
upgrade/downgrade cycles; a populated ledger cannot be dropped by its downgrade.
After the composition refactor, worker tests verified retry/cancellation cleanup
without Firebase or a GPU route map. A retired Apple product was restored only
from an existing verified ledger record, with unknown transactions/product changes
rejected and revocation still applied. Docker build and an offline container check
validated mock fixtures, application factories, protected routes and ORM metadata;
all 18 deployment checks passed.
The official Python SDK adapter has 15 dedicated checks for SDK validation/error
mapping, credential isolation, persisted idempotency, cancellation, operation
deadlines, redirects and bounded concurrency. The SDK-backed provider also passed
the full billing suite on PostgreSQL and an offline Docker integration check.
iOS Development/Production builds and 127 selected test runs passed (subscriptions,
SDK orchestration, lifecycle, navigation, persistence, settings, Keychain,
configuration and localization). These are not real merchant
purchases or a completed remote backup restoration.

After restoring initialization tiers and separating HTTP interceptors, 98 selected
test runs passed, including failure attribution and bearer-header isolation. An
additional isolated simulator test presented and canceled the official SDK form
with `TestModeSettings`; this verifies UI integration, not merchant payment processing.

After separating the Apple/YooKassa catalogs, 31 selected iOS test runs passed,
including period decoding and provider isolation. Provider tests cover all four
YooKassa periods, localized payment descriptions and renewal snapshots after a
catalog price/period change. The supplied merchant was not charged by these tests.

The fast suite uses SQLite. To repeat billing tests against an isolated PostgreSQL:

```sh
# Run from backend/main with DOGLYAD_TEST_POSTGRES_URL pointing to a disposable DB.
../../.venv311/bin/python -m pytest tests/test_billing.py tests/test_sdk_payments.py tests/test_billing_postgres.py tests/test_billing_reconciliation.py
```

Each test creates and drops only its uniquely named `doglyad_test_*` schema.
`test_billing_postgres.py` is skipped when the PostgreSQL test URL is absent.
The `check_billing` CI job supplies an isolated PostgreSQL service, checks the
migration and runs these financial/concurrency checks before image publication.

The pre-release history is consolidated into `0001_initial`, which creates the
complete ledger, SDK metadata, renewal snapshots, dispatch/reconciliation fields,
refund records and Apple environment constraints. Keep this migration as an
explicit schema snapshot. After release, add new revisions instead of rewriting it.
Apply `alembic upgrade head` before starting the API or worker. For an existing
pre-release database, see the backup/schema-verification and stamping procedure
in [BILLING_LOCAL.md](BILLING_LOCAL.md); do not stamp an incomplete schema.
