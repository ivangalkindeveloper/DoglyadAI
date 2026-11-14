# Doglyad architecture and code map

## Architecture

The backend is split into two independently deployable services: `backend/main` and `backend/inference`.

- **Main backend** (`backend/main/`) — Python, FastAPI, Docker. Runs on a **non-GPU VM** and never performs inference itself: it builds the prompt, selects the model, and routes the request. It also sends reports by email through SMTP.
- **Inference service** (`backend/inference/`) — Python, FastAPI, Docker. Runs once per GPU host beside one or more local vLLM engines. It validates App Check, selects the configured engine by `modelId`, and performs model-agnostic structured generation. Existing single-model VMs remain supported; DGX Spark uses one backend and three vLLM containers.
- **iOS application** — SwiftUI, MVVM, SwiftData, Alamofire, Apple Foundation Models for on-device inference, Firebase, StoreKit 2, and backend-owned subscriptions.

Module and root view models use `InitialState`, scenario-specific `LoadingState`, backend-data `SuccessState`, synchronous-screen `DefaultState`, scenario-specific `ErrorState`, and meaningful screen-specific states. Keep the feature prefix. Follow the complete state composition and naming rules in [the iOS instructions](ios.md#swift-ios), including single-state modules and equality between loading scenarios.

A report-generation request follows this path:

```text
iOS ──► backend/main (non-GPU) ──► backend/inference + vLLM (model GPU VM)
```

App Check is validated **twice**: at the system entry point (`backend/main`) and again on the model machine (`backend/inference`). The `X-Firebase-AppCheck` header is forwarded unchanged, so both services validate the same token.

The main-backend check protects the public system entry point. The repeated check prevents direct access to a GPU VM that bypasses the main backend. Both VM groups are controlled by the developer.

Validation cannot be disabled: there is no flag or mode. Every application endpoint lives under the versioned `/v1` router and is protected by App Check in every environment. This includes `/v1/application_config` and the two `/v1/ultrasound/examination_*` configuration endpoints. The iOS client configures Firebase and its App Check interceptor before downloading these documents.

### Billing

The subscription ledger lives in `backend/main` with PostgreSQL and an independent
reconciliation worker. All client `/v1/subscriptions/*` routes retain App Check;
owner-specific operations additionally require an anonymous bearer secret. Base
and Pro are paid tiers. UUIDs and browser redirects never prove access.

`billing.json` contains one `products` array with `id`, `entitlement`, `period`,
`price` (`amountMinor`, `currencyIso2Code`), `titleLocaleKey` and
`priceTemplateLocaleKey`. The backend resolves these keys through `l10n.json`
and returns `title` and `priceTemplate` for the requested language. The protected
`/v1/subscriptions/plans` response uses the same product list.
The catalog also declares `tiers` with `id`, `titleLocaleKey` and
`featureLocaleKeys`. The response resolves them into `id`, `title` and `features`.
Segment labels and benefits come from these entities for both providers. IDs are shared by
Apple and Robokassa. Apple prices and periods come from StoreKit; the catalog's
RUB price applies to Robokassa. Robokassa supports weekly, monthly, six-month and annual
periods; orders and renewals retain their agreed price and month/day intervals.
Client plans use `SubscriptionPeriod` and the `period` field for those four periods.
Subscriptions use only `apple` or `robokassa`. Keep Apple's verified
Production/Sandbox environment in the ledger's separate `apple_environment` field.
Every listed billing product is available for new purchases; do not add availability
flags to this catalog. Removing a product stops offering it. Existing Robokassa
renewals retain their snapshots; previously recorded Apple products retain their
tier for verified restoration and reconciliation even after catalog removal.
Purchase completion must match the selected product and confirmed provider evidence.
Backend payment responses include `planId`; match it and the exact payment ID before accepting
success. Pending StoreKit purchases require a new verified transaction for the selected
product, distinct from the transaction snapshot taken before purchase. An existing
active subscription alone must never close a pending purchase.

Russian iOS storefronts use `SubscriptionRobokassaRepository`; other storefronts
use StoreKit 2. App Check/bearer-protected prepare/check routes create an owner-bound
payment and verify its exact identity. Paywall owns an immutable automatic-renewal
choice, enabled by default. Prepare validates the displayed price, saves that choice
and calls Invoice API. `RobokassaPaymentController` opens Robokassa directly using
a system browser session. Robokassa collects email; ResultURL supplies `EMail`
for renewal contact storage. Technical passwords remain server-only;
no payment SDK or raw card tokens enter the client.

`RobokassaPaymentProvider` uses the lifespan-owned `httpx.AsyncClient`, bounded
responses and absolute deadlines. Persist a unique numeric invoice and merchant/mode
snapshot before dispatch. A lost CreateInvoice response is reconciled by the same
invoice; recurring charges and non-idempotent refunds are never blindly replayed.
Development success requires ResultURL signed with the test password #2. Production
also requires canonical `OpStateExt` state 100, exact amount, merchant and invoice.
`SuccessURL` and mobile callbacks never grant access. Known refund request IDs are
polled separately; lost refund request IDs and cabinet-only refunds need staff review.

Persist dispatch evidence and renewal method snapshots before provider I/O. An
unknown outcome keeps its operation identity even after renewal cancellation.
New purchases may replace only unsent expired renewals under the owner lock. Active Robokassa plan changes charge the full new price and start immediately after verified payment, replacing prior access and renewal schedules without carrying over unused time. Renewal can only be disabled on an existing subscription; enabling requires a new purchase.
Reconcile completed payments as well as pending orders. Store refund IDs, states
and amounts separately from access, including partial refunds; callbacks and
worker retries must not duplicate money or paid periods.

Derive the Robokassa mode from `ENVIRONMENT`: development accepts only test
shops/payments, production accepts only live shops/payments. The server sets
`IsTest=1` before development invoice creation and uses the matching environment
passwords. Never infer test success from a production status query. Keep
the temporary `IS_ROBOKASSA_LIVE_ENABLED=false` launch gate until the real-payment
prerequisites below are implemented; environment selection alone cannot enable
real charges. Do not restore a separate test-mode environment flag.

`app.payment_main:app` serves verified provider callbacks and `/payments/return`,
a plain HTTP redirect to the app with no HTML. Per-route body/rate policies come
from `server.json.endpoints`. There are no merchant-hosted payment forms, browser
cookies, checkout codes or checkout tables. Robokassa notifications require signature verification and production canonical API
verification; Apple transactions/notifications require verified signatures and current
server state. Keep real charges disabled until receipts and Apple external-purchase
reporting are implemented and all merchant/signing prerequisites are met. See
[`backend/main/BILLING.md`](../../backend/main/BILLING.md) and
[`deploy/billing/README.md`](../../deploy/billing/README.md).

## Code map

### `backend/main/` — main backend

| Path | Description |
|---|---|
| `backend/main/app/main.py` | FastAPI application, versioned `/v1` router protected by App Check, rate limiter, and request-ID middleware; delegates startup and shutdown to `MainLifespan` |
| `backend/main/app/core/application/main_lifespan.py` | `MainLifespan`: configuration loading, shared `httpx.AsyncClient`, unconditional App Check initialization, ready `NeuralModelService`, and client cleanup |
| `backend/main/app/route/ultrasound/report_generations/` | Protected, owner-scoped report jobs: start with `POST`, read a snapshot or SSE events with `GET`, and cancel with `POST`. A background worker generates and validates reports. |
| `backend/main/app/model/ultrasound/us_examination_model_report_response.py` | `USExaminationModelReportResponse`: generated report response with model ID, generation date, optional description remarks, and photo remark points; `USExaminationReport` remains the internal structured report model |
| `backend/main/app/schema/us_examination_report_structured_output.py`, `backend/main/app/service/report/report_validator.py` | Request-dependent report schema with localized remark descriptions, photo IDs and normalized coordinates; validates generated remarks against the request |
| `backend/main/app/route/ultrasound/parse_dictation.py` | Protected, rate-limited `POST /v1/ultrasound/parse_dictation`: builds a voice parsing prompt, calls the ready `NeuralModelService`, validates generated fields against the transcript, and returns `USVoiceFormParseResponse` |
| `backend/main/app/route/templates/ready_made_list.py` | Protected, rate-limited `GET /v1/templates/ready_made_list`: returns localized `USExaminationReadyMadeTemplateResponse` values |
| `backend/main/app/route/email/send_report_email.py` | `POST /v1/send_report_email`: sends any report through SMTP (`smtplib`) |
| `backend/main/app/route/localization/l10n.py` | Independent App Check protected `/v1/l10n` router; returns one locale with application strings and voice parsing rules. |
| `backend/main/app/route/configuration/application_config.py` | Protected `/v1/application_config` endpoint. The file is returned as original text without a `response_model`; modeling the full configuration tree would create a second schema that could drift from JSON. |
| `backend/main/app/route/ultrasound/examination_*.py` | Two protected `/v1/ultrasound/examination_*` configuration endpoints. |
| `backend/main/app/core/configuration/variables.py` | Environment variables through `pydantic_settings` (`Variables`): `ENVIRONMENT`, `MODEL_SERVICE_TYPE`, `FIREBASE_CREDENTIALS_PATH`, `EMAIL_*`, and `INFERENCE_ENDPOINTS_PATH`. Operational timeouts and request policies live in server-only `server.json`. Compose supplies values from `backend/main/secrets/.env` and the selected environment profile; `Variables` itself reads the process environment. |
| `backend/main/app/core/app_check/app_check.py` | `AppCheck.initialize()` and `AppCheck.verify()` initialize Firebase and protect every `/v1` route. `AppCheck.HEADER` names the forwarded header. HTTP startup cannot omit Firebase credentials or disable verification. |
| `backend/main/app/core/application/application_factory.py`, `service_factory.py`, `service_dependencies.py` | `ApplicationFactory` creates main/payment HTTP applications and selects each application's policies from the shared `server.json.endpoints` map; `ServiceFactory` composes startup services in `MainContainer`; `ServiceDependencies` returns the existing services to routes. |
| `backend/main/app/database/` | `BillingDatabase` owns the SQLAlchemy engine, session creation and owner locks. Concrete mapped entities end in `DB`; `BillingBase` remains the abstract declarative base. SQL table/column names are independent of Python type names. |
| `backend/main/migrations/versions/` | `0001_initial` creates the complete Apple/Robokassa ledger and report storage. Pre-release schemas are not supported. Downgrade refuses a populated ledger. |
| `backend/main/app/billing_worker.py`, `app/service/billing/billing_worker.py` | CLI entry point and `BillingWorker`: a separate process with its own HTTP client and database pool, using only billing services. It creates no FastAPI application, generation service or App Check initializer. |
| `backend/main/app/core/configuration/` | Environment variables, loading and validation of a per-application `Configuration` snapshot, and configuration dependencies. `ConfigurationResponseService` assembles localized responses; route dependencies access the container without module-global catalogs. |
| `backend/main/app/core/localization/application_localization_validator.py`, `backend/main/app/core/localization/prompt_localization_validator.py` | Validate application and prompt catalog key parity, placeholders, and voice catalog structure across languages |
| `backend/main/app/error/`, `app/core/http/api_error_handler.py`, `app/core/http/api_error_middleware.py` | Typed expected API failures own codes, descriptions and statuses. One handler formats HTTP, validation and body-limit errors; the outer ASGI boundary sanitizes unexpected failures. `ApiErrorResponse` contains `code`, `detail`, `requestId` and optional validation fields. See `backend/main/ERRORS.md`. |
| `backend/main/app/core/http/request_id_middleware.py`, `backend/main/app/core/logging/request_id_log_filter.py` | Request-ID middleware and log context; forwards the request ID to the inference service through `HttpHeader.REQUEST_ID` |
| `backend/main/app/service/neural_model/` | Generation abstraction: `NeuralModelService`, `InferenceService`, `MockNeuralModelService` and `NeuralModelServiceFactory.create()`. The factory selects the implementation once during lifespan and injects it into the application services in `app.state.container`; routes receive those services through FastAPI dependencies. The internal `NeuralModelServiceRequest` lives in `app/model/neural_model/`; GPU transport uses the separate `InferenceGenerationRequest`. |
| `backend/main/app/service/billing/`, `backend/main/app/core/billing/` | Subscription ledger, provider verification, checkout payment processing and browser gateway; protected owner/service dependencies and persisted usage accounting. Billing stays within the main backend. |
| `backend/main/app/service/report/`, `dictation/`, `email/`, `configuration/`, `validation/`, `http/` | Feature services, shared input validation and request limiting. `ServiceDependencies` supplies services; `BillingDependencies` enforces owner/feature access. Localization, HTTP policy and logging helpers belong to their named infrastructure classes. |
| `backend/main/mock/` | Local RU/EN report and voice-generation fixtures, validated at mock-service startup. Report points bind to uploaded photo IDs and optional sections follow the requested schema. Voice proposals require matching evidence in the actual transcript and pass the normal source validator. |
| `backend/main/app/model/` | Pydantic configuration and API models: localization responses, report emails and attachments, neural model settings, `neural_model/` internal service requests and operations, `inference/` transport models, and `ultrasound/` requests, responses, internal reports, voice fields, examination types, templates, and model availability |
| `backend/main/secrets/inference_endpoints.json` | Manually maintained `modelId -> inference service URL` map, read from `INFERENCE_ENDPOINTS_PATH`, with one entry per model. Models on the same host can share a URL. Never committed. |
| `backend/main/app/prompt/` | Prompt generation: one `PromptFactory` in `prompt_factory.py`, initialized with `LanguageCode` and using backend localization catalogs for every language |
| `backend/main/app/prompt/prompt_factory.py` | Resolve voice parsing instructions from backend localization and pack examination title and transcript as JSON; inference receives the completed prompt |
| `backend/main/app/service/dictation/voice_form_validator.py` | Transcript-grounded validation of generated names, dates, gender, numbers, measurements, and clinical text; uses individually named source and evidence functions in `service/dictation/`, preserves evidence, and marks uncertain fields |
| `backend/main/config/` | Environment-specific JSON documents (`development/`, `production/`): `application.json`, `ultrasound_examination_neural_models.json`, grouped `ultrasound_examination_types.json`, `ready_made_templates.json`, and server-only `server.json` for HTTP timeouts, endpoint policies, image/email limits and voice parsing parameters. Each environment has `en/` and `ru/` folders with `l10n.json` for string keys referenced through `*LocaleKey` fields, `l10n_application.json` for enum-keyed client UI strings, `l10n_voice_parsing.json` for injected voice rules, a server-only `l10n_voice_source_validation.json` for transcript evidence validation, and `l10n_ultrasound_examination_contextual_strings.json` mapping examination type IDs to speech phrases. The backend loads them at startup and assembles localized responses for the configuration and template routes. They are baked into the image by `backend/main/Dockerfile`. |
| `backend/main/docker-compose.yml` | Docker Compose reads `backend/main/secrets/.env` and a profile-specific `secrets/.env.<profile>` selected through `ENV_FILE`. Only `./secrets` and `./logs` are mounted; configuration is baked into the image. |
| `backend/main/LOCALIZATION.md` | Localization API, server catalogs, client initialization, bootstrap exceptions, and catalog contract checks |

### `backend/inference/` — inference service

This service runs once per GPU host and routes configured model IDs to local vLLM engines. See [`backend/inference/README.md`](../../backend/inference/README.md) for the full deployment guide.

| Path | Description |
|---|---|
| `backend/inference/app/main.py` | FastAPI application, request-ID middleware, and the only `/v1` router protected entirely by App Check; delegates lifecycle to `InferenceLifespan`. The service has no unauthenticated endpoints; automatic public Swagger, ReDoc, and OpenAPI routes are disabled. |
| `backend/inference/app/core/inference_lifespan.py` | `InferenceLifespan`: shared `httpx.AsyncClient`, unconditional App Check initialization, vLLM service setup, and client cleanup |
| `backend/inference/app/error/`, `app/core/api_error_handler.py`, `app/core/api_error_middleware.py` | Independent implementation of the same API error contract, including safe validation responses, preserved request IDs and retry metadata. Shared schema/metadata contract tests run from main. |
| `backend/inference/app/core/request_id_middleware.py`, `backend/inference/app/core/request_id_log_filter.py` | Request-ID middleware and log context, preserving the ID forwarded by the main backend |
| `backend/inference/app/route/generation.py` | `POST /v1/generation`: accepts ready prompts, images, and a JSON Schema string and returns structured generated content |
| `backend/inference/app/service/vllm_service.py` | `VLLMService`: selects a configured private vLLM URL by `modelId`, rejects unknown IDs, and maintains a separate bounded queue per model; lifespan creates its instance and `get_vllm_service` injects it into the route |
| `backend/inference/app/core/init_app_check.py`, `backend/inference/app/core/verify_app_check.py` | Second App Check initialization and validation on the model machine, protecting `/v1`. Validation is **unconditional**: the service cannot start without Firebase credentials, and there is no bypass. |
| `backend/inference/app/core/variables.py` | `FIREBASE_CREDENTIALS_PATH`, the `VLLM_ENDPOINTS` JSON map or the existing `SERVED_MODEL_ID` / `VLLM_BASE_URL` pair. Startup rejects missing, empty, ambiguous or invalid routes. This service has no `ENVIRONMENT`. |
| `backend/inference/docker-compose.yml` | Two containers: `vllm` (model image and GPU) and `inference_backend` (the service). Start with `--env-file secrets/.env` through `make start-backend-inference`. |

### `ios/` — iOS application

| Path | Description |
|---|---|
| `ios/Doglyad/Application/Application/` | Entry point `Application.swift`, `ApplicationRootViewModel`, root views (`MainRootView`, `ErrorRootView`), and router (`DRouter`, `RouteType`) |
| `ios/Doglyad/Application/Application/Manager/` | Application managers, including `PermissionManager` and `ConnectionManager` |
| `ios/Doglyad/Application/Application/View/` | Application views reused across multiple feature modules, composed exclusively from `DoglyadUI` components. Views used by only one module belong in that module and use its name as their type-name prefix. |
| `ios/Doglyad/Application/Module/` | Screen and bottom-sheet features follow the required `FeatureScreen` / `FeatureBottomSheet`, `FeatureScreenView` / `FeatureBottomSheetView`, `FeatureViewModel`, and `FeatureArguments` structure. Every module also contains a `Preview/` folder with `FeaturePreview.swift` for named previews of all states and `FeaturePreviewView.swift` for the module preview wrapper. Current feature groups: `About`, `History`, `ImportMedia`, `LegalUpdate`, `LimitExceeded`, `NewVersion`, `OnBoarding`, `Permission`, `PhotoView`, `Report`, `Scan`, `Select`, `Menu`, `SettingsAI`, `Share`, `Storage`, `Subscription`, `Template`, `WorkSettings`, and `WebDocument`. |
| `ios/Doglyad/Application/Module/Menu/`, `SettingsAI/`, `WorkSettings/` | Independent modules for application navigation, AI configuration and work settings. |
| `ios/Doglyad/Application/Application/ViewModel/` | `DStateViewModel<State>` publishes immutable lifecycle states through `emit`. `DModuleViewModel<State>` adds module lifecycle, analytics, coordination, and a shared subscription snapshot. Shared screen data and controllers belong to the owning view model; controllers are observed with `NestedObservableObject`. |
| `ios/Doglyad/Application/Application/ViewModel/Subscription/`, `ios/Doglyad/Application/Application/ViewModel/Ultrasound/` | `SubscriptionRootViewModel` and `UltrasoundRootViewModel` own shared state. Each root view model lives beside its `State/` composition in the corresponding feature folder; modules receive getter, update, and observation closures instead of root instances. |
| `ios/Doglyad/Application/Module/**/ViewModel/` | Every module's view model, focus/input types, and `State/` composition: a module-specific class-bound state protocol and concrete state classes. Root features also keep their view models and state compositions in their owning application area. |
| `ios/Doglyad/Application/Application/Coordinator/` | Navigation and flow orchestration, including initial routing, onboarding, model selection, and subscription gating; subscription state is accessed through closures |
| `ios/Doglyad/Application/Application/Analytics/` | Analytics manager, screen and bottom-sheet destinations, event names, and structured parameters |
| `ios/Doglyad/Application/Module/Scan/ScanSpeech/` | Voice recording, automatic parsing of finished transcripts, speech confidence and review policies, and automatic/uncertain field review plans |
| `ios/Doglyad/Application/Module/Permission/` | One `PermissionBottomSheet` module with `PermissionArguments.Kind` for camera, speech, or photo-library access; the `Library/` submodule adapts the system photo picker. |
| `ios/Doglyad/Application/Module/Subscription/` | `Paywall`, `SubscriptionManage` and `SubscriptionRecovery` screens with backend UI strings. Management displays the current plan, expiry, server-owned benefits and provider renewal actions; management copies the permanent recovery key; the recovery screen only accepts a key and restores access. Settings opens `SubscriptionManage` directly; its change-plan action pushes `Paywall` and returns to management afterward. Paywall fetches its catalog through the repository factory. Immutable loaded states own plans, tier metadata and selection; purchase and pending states retain those data. Initial load failures and operation failures use separate states. `SubscriptionRestoreStrategy` is shared by repositories, the root and modules. The root refreshes and publishes subscription status before returning `.completed`; modules use that shared status to distinguish restored access from no purchases, and `.recoveryKeyRequired` opens the recovery form. Root closures expose shared subscription state and operations that change it; `SubscriptionRootViewModel` owns status, the pending purchase context and generic result, and transaction/purchase tasks, without storefront state or observation. |
| `ios/Doglyad/Repository/Subscription/` | Immutable `SubscriptionStoreKitRepository` and `SubscriptionRobokassaRepository` implement provider operations. `SubscriptionRepositoryFactory.make()` reads the current storefront through an explicitly injected getter and constructs the repository for catalogs and purchases. Provider repositories validate the selected plan's source. Before presenting payment UI they pass an immutable `SubscriptionPurchaseContextProtocol` to the root. The Robokassa context checks the exact payment and plan IDs; the StoreKit context matches already verified transaction events against the prior transaction snapshot. The root caches generic results and refreshes access after confirmation, without inspecting provider references. A separate injected StoreKit repository observes, synchronizes, restores and manages Apple purchases independently of storefront. Initialization retains the factory and the StoreKit dependency without a storefront snapshot. `SubscriptionBackendRepository` owns shared HTTP/Keychain access. StoreKit supplies Apple prices and periods. |
| `ios/Doglyad/Application/Module/Report/` | `ReportDetail` and `ReportReceived`: saved and newly generated reports, previous model responses, photos, copying, and delivery to work email |
| `ios/Doglyad/Application/Module/PhotoView/`, `ios/Doglyad/Application/Module/PhotoRemark/` | Zoomable photos with normalized remark points, persisted visibility, and a Blur bottom sheet for the selected image remark |
| `ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/` | Downloading, searching, and selecting localized templates supplied by the backend |
| `ios/Doglyad/Core/DependencyContainer.swift` | Dependency-injection container for repositories, managers, configuration, the neural model, the initial screen, and subscription state |
| `ios/Doglyad/Core/Initialization/` | Initialization through the `DependencyInitializer` package. `InitializationProcess` is filled by `StepSet` values in `stepsTier1…stepsTier5`, each with synchronous and asynchronous steps; Tier 5 awaits repository reads and provides the initial settings snapshots; `toContainer` produces the final `DependencyContainer`. |
| `ios/Doglyad/Core/Environment/` | `EnvironmentProtocol` and `EnvironmentType` for development and production configuration |
| `ios/Doglyad/Domain/` | Domain models: `Ultrasound/`, `Config/`, `Localization/`, `Subscription/`, `Billing/`, `SettingsAI`, `TranscriberType`, `TranscriptParserType`, and `PatientGender` |
| `ios/Doglyad/Domain/Subscription/` | Subscription models, including `SubscriptionPaidFeature`, `SubscriptionPeriod`, entitlements and access status. |
| `ios/Doglyad/Domain/Billing/` | All application-owned `Billing*` models: backend request/response models and payment state shared by repositories and the browser checkout adapter. This folder is a sibling of `Subscription/`; application models have no `DTO` suffix. |
| `ios/Doglyad/Domain/Config/*Config.swift`, `backend/main/app/model/*_config.py` | Independent module settings for Scan, ScanSpeech, template creation/editing/list, WorkSettings and SettingsAI. Input maxima come from the matching public `application.json` section. `ApplicationModuleConfig` validates the backend subset; client decoding requires each module section. |
| `ios/Doglyad/Repository/` | Repository protocols and implementations for reports, drafts and draft photos, AI settings, shared data, StoreKit/backend subscriptions, ready-made and saved templates, and user settings. `Report/` also contains the application HTTP transport for server voice parsing. |
| `ios/Doglyad/Utility/` | Framework and package extensions in `Extension/`, mock data and factories in `Mock/`, view modifiers in `Modifier/`, and integration classes tightly coupled to external packages, such as `AppCheckProviderFactory` and `AppCheckHttpInterceptor` in `AppCheck/` |
| `ios/Doglyad/Utility/Extension/` | Extensions of types from frameworks and external packages used by the client |
| `ios/Doglyad/Assets.xcassets` | Application bundle images, icons, and other visual assets permitted alongside resources supplied through `DoglyadUI` |
| `ios/Doglyad/Application/Application/L10N/L10N.swift` | Immutable server catalog in `DependencyContainer`, enum `L10NKey`, UI resources and literal template substitution. Downloaded first in Tier 4 from protected `/v1/l10n`. |
| `ios/Doglyad/Resources/Localizable.xcstrings` | Bootstrap strings for initialization errors and mandatory major-version updates only. System permission/display-name strings remain in `InfoPlist.xcstrings` because iOS reads the installed bundle. |
| `ios/Doglyad.xcodeproj/project.pbxproj` | DoglyadUI currently uses synchronized-folder membership exceptions for both app and framework targets. New DoglyadUI files must be listed in both exception sets to compile only in the design-system framework. `LM_SKIP_METADATA_EXTRACTION` skips the unused App Intents metadata stage in all configurations; remove it when introducing App Intents or App Shortcuts. |
| `ios/DoglyadUI/` | Required design system for client UI: `DTheme`, Montserrat fonts, reusable controls such as `DSegment`, `DToggle`, `DDatePicker`, `DShareLink`, `DCloseButton`, and `DCard`, presentation primitives such as `DImage`, `DProgress`, `DAudioMeter`, `DPageIndicator`, `DCardBackground`, `DCaptureFrame`, and `DTextFade`, and `DMessage`, visual resources, and loading placeholders through `DShimmerPlaceholder` and shimmer through `DShimmerModifier` / `dShimmer` |
| `ios/DoglyadDatabase/` | `DDatabase`, SwiftData `Entity/*DB.swift` entities, actor stores in `Store/` for reports, drafts, and templates, UserDefaults wrappers, and keychain billing identity persistence in `Security/` |
| `ios/DoglyadNetwork/` | Alamofire clients in `Client/`, interceptor contracts and `DLocaleInterceptor` in `Interceptor/`, `DHttpHeader`, and `DHttpErrorProtocol` |
| `ios/DoglyadNeuralModel/` | Foundation Models extraction, domain contracts, and validation for ultrasound text |
| `ios/DoglyadCamera/` | Camera implementation: `DCameraControllerProtocol` and `DCameraView` |
| `ios/DoglyadSpeech/` | Speech recognition: `DSpeechController` implementations and lexicon correction |
| `ios/Config/` | Build configuration. `.xcconfig` files define `ENVIRONMENT` and `BASE_URL`. RevenueCat keys are removed. Checkout URLs arrive from the protected backend response; merchant secrets never enter client configuration. Xcode schemes select the matching configuration; files are never copied or swapped. |
| `ios/Firebase/` | Environment-specific Firebase configuration. A Run Script phase places the matching `GoogleService-Info.plist` in the bundle according to `$CONFIGURATION`; files are not committed. |

### Supporting code

| Path | Description |
|---|---|
| `ios/DoglyadTests/` | Application, localization, draft, navigation, subscription, and voice parsing checks. `VoiceSupport/` contains experimental models and comparison adapters; `LocalizationFixtures/` links to backend development catalogs. |
| `backend/main/tests/`, `backend/inference/tests/` | Independent backend checks for authentication, localization/configuration contracts, generation, source validation, email, and inference routing |
| `evaluation/voice/` | Text, audio, device, replay, and end-to-end speech quality evaluations; follow `README.md` for current evaluation flows and report artifacts |
| `tools/` | Swift and Python formatting pipelines, syntax-aware argument wrapping, and formatter regression tests; see `tools/README.md` |
| `deploy/` | VM bootstrap, Compose and Caddy deployment files, fleet inventory/update orchestration, verification, rollback, and deployment tests; see `deploy/README.md` |
| `deploy/inference/` | Per-host profiles and a stdlib Compose generator; generates local vLLM routes and sequential startup files. Fleet targets reference profiles; backend updates preserve every configured engine. See `deploy/inference/README.md`. |
| `docs/legal/` | Hosted privacy policy and terms, shared rendering code, styles, and bundled web fonts |
