# Doglyad — AI assistant for ultrasound examination analysis

Doglyad is an AI assistant that analyzes ultrasound images together with patient history and generates a medical report.

## Product rules

- **Purpose:** Optimize and automate the work of physicians and other medical professionals. When designing or refactoring any feature, prioritize ease of use and let the application take over routine work so the clinician can focus on the examination.
- **Design approach:** Start every feature design or refactoring from the clinician's goal and the routine work needed to achieve it. Identify which steps the application can perform, then design a flow that reaches the result with the fewest necessary interactions. Evaluate it by the clinician's time, effort, and convenience throughout the task, including data entry and delivery of the resulting report. Avoid unnecessary screens, repeated entry, and redundant confirmations.

### Examples of the design approach

These examples explain why the features exist and illustrate how to apply the product rules when designing or refactoring features.

**Voice form filling:** A clinician can fill scan fields manually, and the toolbar makes moving focus between fields convenient. Even with that toolbar, entering all examination data by hand is slow and requires many interactions. Voice filling lets the clinician dictate the necessary information naturally during the examination while the application extracts it into the appropriate fields. The feature's goal is to take over routine form entry and reduce interruptions to the examination. Extract as much as possible while preserving the meaning, medical terminology, measurements, and units, without inventing missing information. When interpretation is uncertain, ask for confirmation or correction only for the affected fields or speech fragments, retaining reliably interpreted data without requiring the clinician to repeat or reconfirm the entire form.

**Sending a report to work email:** The clinician needs to receive the completed report at work and transfer it into the medical information system. Copying the report and sending it through other services adds routine steps. Sending it directly to the configured work email in one action removes those steps and makes the report available in the clinician's work mailbox. The feature's goal is to simplify the path from the completed examination report to its use in the clinician's existing workflow.

## Architecture

The backend is split into two independently deployable services: `backend/main` and `backend/inference`.

- **Main backend** (`backend/main/`) — Python, FastAPI, Docker. Runs on a **non-GPU VM** and never performs inference itself: it builds the prompt, selects the model, and routes the request. It also sends reports by email through SMTP.
- **Inference service** (`backend/inference/`) — Python, FastAPI, Docker. Runs on a **GPU VM** (one VM per model) beside local vLLM and the model. It validates App Check and performs model-agnostic structured generation.
- **iOS application** — SwiftUI, MVVM, SwiftData, Alamofire, Apple Foundation Models for on-device inference, Firebase, and RevenueCat for subscriptions.

A report-generation request follows this path:

```text
iOS ──► backend/main (non-GPU) ──► backend/inference + vLLM (model GPU VM)
```

App Check is validated **twice**: at the system entry point (`backend/main`) and again on the model machine (`backend/inference`). The `X-Firebase-AppCheck` header is forwarded unchanged, so both services validate the same token.

The main-backend check protects the public system entry point. The repeated check prevents direct access to a GPU VM that bypasses the main backend. Both VM groups are controlled by the developer.

Validation cannot be disabled: there is no flag or mode. Every application endpoint lives under the versioned `/v1` router and is protected by App Check in every environment. This includes `/v1/application_config` and the two `/v1/ultrasound/examination_*` configuration endpoints. The iOS client configures Firebase and its App Check interceptor before downloading these documents.

### Environments

`ENVIRONMENT` (`development` or `production`) selects a directory under `backend/main/config/` and does nothing else. The application reads the same documents from this backend instead of the repository. Otherwise, pushing a new model to `master` could expose it to the app before the backend deployment knows about it, causing a physician to receive `400`. With the default `MODEL_SERVICE_TYPE=inference`, both environments use the same inference route and token validation. A development-staging check is meaningful because it exercises the same code and path; only the model list, examination types, and application settings differ.

`MODEL_SERVICE_TYPE` selects the main backend's generation implementation independently of `ENVIRONMENT`: `inference` calls GPU VMs, while `mock` returns local RU/EN fixtures. VS Code's `Backend: Local Mock` profile selects `mock` with development configuration. App Check, configuration, localization, request validation, and SMTP remain real. Mock generation does not require an inference endpoint map; see [`backend/main/README.md`](backend/main/README.md).

### Timeouts

Timeouts are strictly nested from outside to inside, with each wrapper wider than the operation it contains:

```text
iOS client                    300  application.json -> network.timeoutIntervalForRequest
INFERENCE_REQUEST_TIMEOUT     130  main backend waits for the GPU VM
VLLM_REQUEST_TIMEOUT          120  inference VM waits for its local engine
```

An inner timeout must be shorter than its outer timeout; otherwise the caller can terminate the connection while the wrapped generation is still running.

With `MODEL_SERVICE_TYPE=inference`, every published model must have an entry in `backend/main/secrets/inference_endpoints.json` containing the URL of its GPU VM. A missing mapping is a configuration error.

## Code map

### `backend/main/` — main backend

| Path | Description |
|---|---|
| `backend/main/app/main.py` | FastAPI application, versioned `/v1` router protected by App Check, rate limiter, and request-ID middleware; delegates startup and shutdown to `MainLifespan` |
| `backend/main/app/core/main_lifespan.py` | `MainLifespan`: configuration loading, shared `httpx.AsyncClient`, unconditional App Check initialization, ready `NeuralModelService`, and client cleanup |
| `backend/main/app/route/ultrasound/generate_report.py` | `POST /v1/ultrasound/generate_report`: accepts examination data, calls `NeuralModelService`, validates the structured result, and returns a report with description, conclusion, and optional recommendations |
| `backend/main/app/model/ultrasound/us_examination_model_report_response.py` | `USExaminationModelReportResponse`: generated report response with model ID, generation date, optional description remarks, and photo remark points; `USExaminationReport` remains the internal structured report model |
| `backend/main/app/schema/us_examination_report_structured_output.py`, `backend/main/app/service/validate_report_remarks.py` | Request-dependent report schema with localized remark descriptions, photo IDs and normalized coordinates; validates generated remarks against the request |
| `backend/main/app/route/ultrasound/parse_dictation.py` | Protected, rate-limited `POST /v1/ultrasound/parse_dictation`: builds a voice parsing prompt, calls the ready `NeuralModelService`, validates generated fields against the transcript, and returns `USVoiceFormParseResponse` |
| `backend/main/app/route/templates/ready_made_list.py` | Protected, rate-limited `GET /v1/templates/ready_made_list`: returns localized `USExaminationReadyMadeTemplateResponse` values |
| `backend/main/app/route/send_report_email.py` | `POST /v1/send_report_email`: sends any report through SMTP (`smtplib`) |
| `backend/main/app/route/l10n.py` | Independent App Check protected `/v1/l10n` router; returns one locale with application strings and voice parsing rules. |
| `backend/main/app/route/application_config.py` | Protected `/v1/application_config` endpoint. The file is returned as original text without a `response_model`; modeling the full configuration tree would create a second schema that could drift from JSON. |
| `backend/main/app/route/ultrasound/examination_*.py` | Two protected `/v1/ultrasound/examination_*` configuration endpoints. |
| `backend/main/app/core/variables.py` | Environment variables through `pydantic_settings` (`Variables`): `ENVIRONMENT`, `MODEL_SERVICE_TYPE`, `FIREBASE_CREDENTIALS_PATH`, `EMAIL_*`, `INFERENCE_ENDPOINTS_PATH`, and timeouts. Compose supplies values from `backend/main/secrets/.env` and the selected environment profile; `Variables` itself reads the process environment. |
| `backend/main/app/core/init_app_check.py`, `backend/main/app/core/verify_app_check.py` | Entry-point App Check initialization and verification; `APP_CHECK_HEADER` and the dependency attached to `/v1` live in `verify_app_check.py`. Validation is unconditional; the backend cannot start without Firebase credentials. |
| `backend/main/app/core/load_configs.py` | Loads and stores configuration entities and per-language catalogs at startup, validating locale references and examination type IDs. Individual `get_*` and `resolve_*` functions in `core/` expose the loaded configuration and assemble localized API responses. |
| `backend/main/app/core/validate_application_localizations.py`, `backend/main/app/core/validate_prompt_localizations.py` | Validate application and prompt catalog key parity, placeholders, and voice catalog structure across languages |
| `backend/main/app/core/request_id_middleware.py`, `backend/main/app/core/request_id_log_filter.py` | Request-ID middleware and log context; forwards the request ID to the inference service through `HttpHeader.REQUEST_ID` |
| `backend/main/app/service/` | Generation abstraction: `NeuralModelService` in `neural_model_service.py`, `InferenceService` in `inference_service.py`, `MockNeuralModelService` in `mock_neural_model_service.py`, and internal `NeuralModelServiceRequest` in `app/model/neural_model/neural_model_service_request.py` with an operation and language. `create_model_service()` in `create_model_service.py` selects the implementation once during lifespan and stores it in `app.state.model_service`; routes only call the ready service. GPU transport uses the separate `InferenceGenerationRequest`. |
| `backend/main/app/mock/` | Local RU/EN report and voice-generation fixtures, validated at mock-service startup. Report points bind to uploaded photo IDs and optional sections follow the requested schema. Voice proposals require matching evidence in the actual transcript and pass the normal source validator. |
| `backend/main/app/model/` | Pydantic configuration and API models: localization responses, report emails and attachments, neural model settings, `neural_model/` internal service requests and operations, `inference/` transport models, and `ultrasound/` requests, responses, internal reports, voice fields, examination types, templates, and model availability |
| `backend/main/secrets/inference_endpoints.json` | Manually maintained `modelId -> GPU VM URL` map, read from `INFERENCE_ENDPOINTS_PATH`, with one entry per VM. Never committed. |
| `backend/main/app/prompt/` | Prompt generation: one `PromptFactory` in `prompt_factory.py`, initialized with `LanguageCode` and using backend localization catalogs for every language |
| `backend/main/app/prompt/voice_form_system_prompt.py`, `backend/main/app/prompt/voice_form_prompt.py` | Resolve voice parsing instructions from backend localization and pack examination title and transcript as JSON; inference receives the completed prompt |
| `backend/main/app/service/validate_voice_form_generation.py` | Transcript-grounded validation of generated names, dates, gender, numbers, measurements, and clinical text; uses individually named source and evidence functions in `service/`, preserves evidence, and marks uncertain fields |
| `backend/main/config/` | Environment-specific JSON documents (`development/`, `production/`): `application.json`, `ultrasound_examination_neural_models.json`, grouped `ultrasound_examination_types.json`, `ready_made_templates.json`, and `voice_form_parsing.json` for the server parsing model and token limit. Each environment has `en/` and `ru/` folders with `l10n.json` for string keys referenced through `*LocaleKey` fields, `l10n_application.json` for enum-keyed client UI strings, `l10n_voice_parsing.json` for injected voice rules, and `l10n_ultrasound_examination_contextual_strings.json` mapping examination type IDs to speech phrases. The backend loads them at startup and assembles localized responses for the configuration and template routes. They are baked into the image by `backend/main/Dockerfile`. |
| `backend/main/docker-compose.yml` | Docker Compose reads `backend/main/secrets/.env` and a profile-specific `secrets/.env.<profile>` selected through `ENV_FILE`. Only `./secrets` and `./logs` are mounted; configuration is baked into the image. |
| `backend/main/LOCALIZATION.md` | Localization API, server catalogs, client initialization, bootstrap exceptions, and catalog contract checks |

### `backend/inference/` — inference service

This service runs on a GPU VM, one VM per model. See [`backend/inference/README.md`](backend/inference/README.md) for the full deployment guide.

| Path | Description |
|---|---|
| `backend/inference/app/main.py` | FastAPI application, request-ID middleware, and the only `/v1` router protected entirely by App Check; delegates lifecycle to `InferenceLifespan`. The service has no unauthenticated endpoints; automatic public Swagger, ReDoc, and OpenAPI routes are disabled. |
| `backend/inference/app/core/inference_lifespan.py` | `InferenceLifespan`: shared `httpx.AsyncClient`, unconditional App Check initialization, vLLM service setup, and client cleanup |
| `backend/inference/app/core/request_id_middleware.py`, `backend/inference/app/core/request_id_log_filter.py` | Request-ID middleware and log context, preserving the ID forwarded by the main backend |
| `backend/inference/app/route/generation.py` | `POST /v1/generation`: accepts ready prompts, images, and a JSON Schema string and returns structured generated content |
| `backend/inference/app/service/vllm_service.py` | `VLLMService`: calls local vLLM through the OpenAI-compatible `/v1/chat/completions` endpoint and checks `modelId` against `SERVED_MODEL_ID`; `init_services.py` and `resolve_vllm_service.py` initialize and expose its shared instance |
| `backend/inference/app/core/init_app_check.py`, `backend/inference/app/core/verify_app_check.py` | Second App Check initialization and validation on the model machine, protecting `/v1`. Validation is **unconditional**: the service cannot start without Firebase credentials, and there is no bypass. |
| `backend/inference/app/core/variables.py` | `FIREBASE_CREDENTIALS_PATH`, `SERVED_MODEL_ID`, and `VLLM_*`. This service has no `ENVIRONMENT` because it has no environment-specific configuration documents. |
| `backend/inference/docker-compose.yml` | Two containers: `vllm` (model image and GPU) and `inference_backend` (the service). Start with `--env-file secrets/.env` through `make start-backend-inference`. |

### `ios/` — iOS application

| Path | Description |
|---|---|
| `ios/Doglyad/Application/Application/` | Entry point `Application.swift`, `ApplicationRootViewModel`, root views (`MainRootView`, `ErrorRootView`), and router (`DRouter`, `RouteType`) |
| `ios/Doglyad/Application/Application/Manager/` | Application managers, including `PermissionManager` and `ConnectionManager` |
| `ios/Doglyad/Application/Application/View/` | Application views reused across multiple feature modules, composed exclusively from `DoglyadUI` components. Views used by only one module belong in that module and use its name as their type-name prefix. |
| `ios/Doglyad/Application/Module/` | Screen and bottom-sheet features follow the required `FeatureScreen` / `FeatureBottomSheet`, `FeatureScreenView` / `FeatureBottomSheetView`, `FeatureViewModel`, and `FeatureArguments` structure. Current feature groups: `About`, `History`, `ImportMedia`, `LegalUpdate`, `LimitExceeded`, `NeuralModelSettings`, `NewVersion`, `OnBoarding`, `Permission`, `PhotoView`, `Report`, `Scan`, `Select`, `Settings`, `Share`, `Storage`, `Subscription`, `Template`, `UserSettings`, and `WebDocument`. |
| `ios/Doglyad/Application/Application/ViewModel/` | `DModuleViewModel` owns common module lifecycle, analytics, and subscription snapshots. `SubscriptionRootViewModel` and `UltrasoundRootViewModel` own shared state; modules receive getter, update, and observation closures instead of root instances. |
| `ios/Doglyad/Application/Application/Coordinator/` | Navigation and flow orchestration, including initial routing, onboarding, model selection, and subscription gating; subscription state is accessed through closures |
| `ios/Doglyad/Application/Application/Analytics/` | Analytics manager, screen and bottom-sheet destinations, event names, and structured parameters |
| `ios/Doglyad/Application/Module/Scan/ScanSpeech/` | Voice recording, automatic parsing of finished transcripts, speech confidence and review policies, and automatic/uncertain field review plans |
| `ios/Doglyad/Application/Module/Permission/` | One `PermissionBottomSheet` module with `PermissionArguments.Kind` for camera, speech, or photo-library access; the `Library/` submodule adapts the system photo picker. |
| `ios/Doglyad/Application/Module/Subscription/` | DoglyadUI paywall and customer-center modules with backend UI strings; `SubscriptionRepositoryProtocol` owns plan fetching, purchases, restoration, App Store management, and refunds through RevenueCat. Store prices are runtime product data. |
| `ios/Doglyad/Application/Module/Report/` | `ReportDetail` and `ReportReceived`: saved and newly generated reports, previous model responses, photos, copying, and delivery to work email |
| `ios/Doglyad/Application/Module/PhotoView/`, `ios/Doglyad/Application/Module/PhotoRemark/` | Zoomable photos with normalized remark points, persisted visibility, and a Blur bottom sheet for the selected image remark |
| `ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/` | Downloading, searching, and selecting localized templates supplied by the backend |
| `ios/Doglyad/Core/DependencyContainer.swift` | Dependency-injection container for repositories, managers, configuration, the neural model, the initial screen, and subscription state |
| `ios/Doglyad/Core/Initialization/` | Initialization through the `DependencyInitializer` package. `InitializationProcess` is filled by `StepSet` values in `stepsTier1…stepsTier5`, each with synchronous and asynchronous steps; `toContainer` produces the final `DependencyContainer`. |
| `ios/Doglyad/Core/Environment/` | `EnvironmentProtocol` and `EnvironmentType` for development and production configuration |
| `ios/Doglyad/Domain/` | Domain models: `Ultrasound/`, `Config/`, `Localization/`, `Subscription/`, `NeuralModelSettings`, and `PatientGender` |
| `ios/Doglyad/Repository/` | Repository protocols and implementations for reports, drafts and draft photos, models, shared data, RevenueCat subscriptions, ready-made and saved templates, and user settings. `Report/` also contains the application HTTP transport for server voice parsing. |
| `ios/Doglyad/Utility/` | Framework and package extensions in `Extension/`, mock data and factories in `Mock/`, view modifiers in `Modifier/`, and integration classes tightly coupled to external packages, such as `AppCheckProviderFactory` and `AppCheckHttpInterceptor` in `AppCheck/` |
| `ios/Doglyad/Utility/Extension/` | Extensions of types from frameworks and external packages used by the client |
| `ios/Doglyad/Assets.xcassets` | Application bundle images, icons, and other visual assets permitted alongside resources supplied through `DoglyadUI` |
| `ios/Doglyad/Application/Application/L10N/L10N.swift` | Immutable server catalog in `DependencyContainer`, enum `L10NKey`, UI resources and literal template substitution. Downloaded first in Tier 4 from protected `/v1/l10n`. |
| `ios/Doglyad/Resources/Localizable.xcstrings` | Bootstrap strings for initialization errors and mandatory major-version updates only. System permission/display-name strings remain in `InfoPlist.xcstrings` because iOS reads the installed bundle. |
| `ios/Doglyad.xcodeproj/project.pbxproj` | DoglyadUI currently uses synchronized-folder membership exceptions for both app and framework targets. New DoglyadUI files must be listed in both exception sets to compile only in the design-system framework. `LM_SKIP_METADATA_EXTRACTION` skips the unused App Intents metadata stage in all configurations; remove it when introducing App Intents or App Shortcuts. |
| `ios/DoglyadUI/` | Required design system for client UI: `DTheme`, Montserrat fonts, reusable controls such as `DSegment`, `DToggle`, `DDatePicker`, `DShareLink`, `DCloseButton`, and `DButtonCard`, presentation primitives such as `DImage`, `DProgress`, `DAudioMeter`, `DPageIndicator`, `DCardBackground`, `DCaptureFrame`, and `DTextFade`, and `DMessage`, visual resources, and loading placeholders through `DShimmerPlaceholder` and shimmer through `DShimmerModifier` / `dShimmer` |
| `ios/DoglyadDatabase/` | `DDatabase`, SwiftData `Entity/*DB.swift` entities, actor stores in `Store/` for reports, drafts, and templates, UserDefaults wrappers, and keychain/request-limit persistence in `Security/` |
| `ios/DoglyadNetwork/` | Alamofire clients in `Client/`, interceptor contracts in `Interceptor/`, `DHttpHeader`, and `DHttpError` |
| `ios/DoglyadNeuralModel/` | Foundation Models extraction, domain contracts, and validation for ultrasound text |
| `ios/DoglyadCamera/` | Camera implementation: `DCameraController` and `DCameraView` |
| `ios/DoglyadSpeech/` | Speech recognition: `DSpeechController` implementations and lexicon correction |
| `ios/Config/` | Build configuration. Development and production `.xcconfig` files define `ENVIRONMENT`, `BASE_URL`, and `REVENUECAT_API_KEY`. Xcode schemes select the matching configuration; files are never copied or swapped. |
| `ios/Firebase/` | Environment-specific Firebase configuration. A Run Script phase places the matching `GoogleService-Info.plist` in the bundle according to `$CONFIGURATION`; files are not committed. |

### Supporting code

| Path | Description |
|---|---|
| `ios/DoglyadTests/` | Application, localization, draft, navigation, subscription, and voice parsing checks. `VoiceSupport/` contains experimental models and comparison adapters; `LocalizationFixtures/` links to backend development catalogs. |
| `backend/main/tests/`, `backend/inference/tests/` | Independent backend checks for authentication, localization/configuration contracts, generation, source validation, email, and inference routing |
| `evaluation/voice/` | Text, audio, device, replay, and end-to-end speech quality evaluations; follow `README.md` for current evaluation flows and report artifacts |
| `tools/` | Swift formatting pipeline, SwiftSyntax argument wrapping, and formatter regression tests; see `tools/README.md` |
| `deploy/` | VM bootstrap, Compose and Caddy deployment files, fleet inventory/update orchestration, verification, rollback, and deployment tests; see `deploy/README.md` |
| `docs/legal/` | Hosted privacy policy and terms, shared rendering code, styles, and bundled web fonts |

## Code style

- **Boolean flags:** Name every boolean flag with the `is` prefix, for example `isChecked`, `isAvailable`, and `isRemarksVisible`. Use `is_` in Python snake_case names, for example `is_available`; fields shared with iOS use camelCase, for example `isAvailable`.
- **API string contract:** Required response strings must contain non-whitespace text. Normalize blank optional strings to `null` on the backend, including strings assembled there. Clients rely on optional presence and do not repeat empty-string checks for validated response fields.

### Design and refactoring

- **Release status and compatibility:** The application has not been released. Until the first release, refactoring does not require support for previous client versions. Update backend and client contracts, localization keys, and their checks together; do not introduce compatibility aliases, deprecated keys, or adapters solely to support previous client versions.
- **Existing conventions:** Write code consistently with the project's current architecture, naming, structure, and implementation style. Agree on any conceptual or architectural change with the user before implementing it, even when the code change is small.
- **Responsibilities:** Avoid spaghetti code. Keep responsibilities explicit and cohesive, dependencies clear, and coupling low. Use encapsulation, composition, polymorphism, and SOLID principles; choose patterns that solve the actual problem without introducing unnecessary abstractions.
- **Refactoring approval:** Before a refactoring that changes substantial code or many files, present a concrete proposed design: types and their responsibilities, dependency relationships, selected patterns and why they fit, and the migration scope. Obtain the user's approval of that design before starting the refactoring.

Use the following pattern catalog when evaluating a design. Apply relevant patterns rather than requiring every pattern in each feature. The catalog includes classic GoF patterns and common additional patterns; it is not an exhaustive list of every published pattern.

- **Creational (GoF):** Abstract Factory, Builder, Factory Method, Prototype.
- **Structural (GoF):** Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy.
- **Behavioral (GoF):** Chain of Responsibility, Command, Interpreter, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor.
- **Additional object-oriented patterns:** Dependency Injection, Null Object, Object Pool, Specification.
- **Architecture and application patterns:** MVVM (the required client architecture), MVC, MVP, Repository, Unit of Work, Service Layer, Coordinator, Router, Composition Root. Listing an alternative architecture does not authorize replacing the project's existing architecture; such changes require prior agreement.

### Localization

- **Backend ownership:** The main backend is the source of truth for application localization. Keep the client thin: application UI text, language-dependent phrases and words, parsing patterns, numeric vocabularies, and schema descriptions live in backend localization catalogs.
- **Client exceptions:** Local application localization is limited to initialization errors and mandatory major-version update UI, which must work before backend catalogs are available. Mandatory iOS system bundle strings, such as permission descriptions and the display name, remain in `InfoPlist.xcstrings` because iOS reads them from the installed bundle. Do not add local copies or fallbacks for other application text.
- **Feature keys:** Name application UI localization keys as `{featureName}{keyName}` in lower camel case: a feature prefix such as `scan`, `history`, `onBoarding`, or `legalUpdate`, followed by a specific key name starting with an uppercase letter. For example: `scanUserDescription`, `scanServiceAvailabilityDescription`, `historyTitle`, `onBoardingContinueButton`, and `scanPatientNamePlaceholder`. Use the same key names in backend catalogs, `L10NKey`, and the permitted local bootstrap catalog.
- **Key ordering:** Always keep all localization keys in ascending alphabetical order by their full key names in every localization catalog and key declaration, including backend catalogs, `L10NKey`, and permitted client bundle catalogs. Preserve this ordering whenever adding, renaming, or editing keys.
- **Semantic suffixes:** Choose the suffix by the text's UI role. Use the exact spellings `Title`, `Label`, `Description`, `Button`, and `Placeholder`.

| Suffix | Purpose | Example |
|---|---|---|
| `Title` | Screen or bottom-sheet title | `historyTitle` |
| `Label` | Short section or field name | `scanPatientLabel` |
| `Description` | Medium or long explanatory text | `scanServiceAvailabilityDescription` |
| `Button` | Button wording specific to a feature | `scanGenerateReportButton` |
| `Placeholder` | Field placeholder specific to a feature | `scanPatientNamePlaceholder` |

- **Shared buttons:** Use the shared `button` prefix for generic actions that are not tied to a feature, for example `buttonAccept` and `buttonBack`. Reuse these keys across features. When the button phrase belongs to a particular feature, use that feature's prefix and the `Button` suffix instead.
- **Catalog usage:** UI accesses `L10N` with `L10NKey`; views receive it through `.localization(container.l10n)` and `@EnvironmentObject`, and non-UI code receives it through arguments. Select one catalog using `Language.currentLocale` and inject it through arguments. Do not embed or mix localized RU/EN matching rules in Swift models, parsers, or policies. Technical identifiers, protocol syntax, and test input data are not translations.

### Python backend

- **Framework:** FastAPI with Pydantic models.
- **Typing:** Put `from __future__ import annotations` in every file and annotate all functions and values.
- **Naming:** Use snake_case for functions and variables, CamelCase for classes and Pydantic models, and camelCase for Pydantic fields shared with iOS.
- **File names:** Name each implementation file after its single public class or top-level function, converting type names to snake_case: `NeuralModelService` lives in `neural_model_service.py`, `VLLMService` in `vllm_service.py`, and `create_model_service()` in `create_model_service.py`. Avoid generic names such as `base.py`, `factory.py`, or `utils.py` when the implementation has a more specific name.
- **One declaration per file:** A file contains only one class, dataclass, or enum, including private types. A function-based module provides only one public top-level function. Put additional public functions and types in their own named files; private implementation helpers and supporting constants may stay with their owning declaration. A module containing only a shared value, such as `limiter`, is named after that value.
- **Framework files:** Preserve required entry-point and discovery names: `main.py` composes the FastAPI application, `__init__.py` contains package exports without implementations, and pytest uses `conftest.py` and `test_*.py` for fixtures and test functions. These exceptions do not permit grouping application implementations or test helper classes; test doubles also live in separate files named after their classes.
- **Models:** Put each Pydantic model or request dataclass in its own file under `app/model/`. Keep configuration entities separate from localized response models.
- **Response model names:** In both backend services, models returned as HTTP endpoint responses must have the `Response` suffix, for example `GenerateReportResponse` or `GenerationResponse`. Internal models may use any meaningful CamelCase name and have no mandatory suffix.
- **Language and headers:** Use `LanguageCode` and `HttpHeader` in main-backend code; convert enum values to strings at JSON and HTTP boundaries.
- **Concurrency:** Use `async`/`await` for handlers and HTTP calls. Reuse the shared `httpx.AsyncClient` from application state.
- **Configuration:** Read environment values through `pydantic_settings` in `app/core/variables.py`, including values from `backend/main/secrets/.env`.
- **Dependencies:** Pin versions in `requirements.txt`.
- **Inference logs:** Never log request bodies because they contain patient data and images. Log only status, model ID, image count, and string lengths.
- **Inference route construction:** Build the inference path only in `create_model_service()` (`app/service/create_model_service.py`). The same connection applies to all environments. Routes receive a ready `NeuralModelService` from `app.state.model_service` and call it.

### Swift iOS

- **Initialization:** `DependencyInitializer` runs `InitializationProcess` through ordered `StepSet` values in `stepsTier1…stepsTier5`. Each set contains synchronous and asynchronous steps. `ApplicationRootViewModel.initialize()` starts the process, `toContainer` builds `DependencyContainer`, and SwiftUI Environment receives the container.
- **Concurrency:** Use Swift Concurrency (`async`/`await`, `Task`) and `@MainActor` for UI code.
- **Formatting:** Run `make format-ios` and verify with `make lint-ios`. Put every nonempty call argument and declaration parameter on its own line, including single arguments, with a trailing comma. The project combines SwiftFormat with its SwiftSyntax rule; preserve string literals/interpolations and function type syntax. See `tools/README.md`.
- **Design system:** Build client UI exclusively from `DoglyadUI` components and its styling modifiers. SwiftUI provides declarative composition; native or third-party UI controls must not be used directly in application views. Loading states must use the design system's loading components and shimmer, including `DShimmerModifier` / `dShimmer`; do not apply third-party shimmer APIs directly. Add missing generic UI primitives to `DoglyadUI` before using them in features. Required system interfaces for camera/photo-library access, web documents, and StoreKit purchase, management, or refund confirmation are framework adapters; their app-owned layout and surrounding controls still follow these design-system rules.
- **Application components:** Place application views reused across multiple feature modules in `ios/Doglyad/Application/Application/View/`. Compose these views from `DoglyadUI` components. A view used only by one feature module must remain inside that module, and its type name must start with the module's name, for example `ScanTemplateCardView` in the `Scan` module. Keep generic design-system primitives in `DoglyadUI`.
- **Visual resources:** Use images, animations, icons, and other visual assets only when supplied through `DoglyadUI` or the application bundle's `ios/Doglyad/Assets.xcassets`. Do not use resources directly from system frameworks or third-party frameworks in application views, including direct SF Symbols via `Image(systemName:)`.
- **Architecture:** Follow MVVM. Module view models inherit from `DModuleViewModel`. Every screen or bottom-sheet feature must contain `FeatureScreen` / `FeatureBottomSheet` (SwiftUI entry view), `FeatureArguments` (module input), `FeatureScreenView` / `FeatureBottomSheetView` (pure presentation view), and `FeatureViewModel` (`ObservableObject` with presentation logic). The entry view accepts `FeatureArguments`, creates a `FeatureViewModel` instance, and passes it as an argument to its presentation view. When a view model depends on `DependencyContainer`, pass the entire container rather than individual dependencies.
- **State:** Use `ObservableObject` and `@Published` for scalar state, `@NestedObservableObject` for nested observable controllers, `@StateObject` for view-model ownership, `@EnvironmentObject private` for environment injection, `@ObservedObject` for externally owned controllers other than the feature view model, and `@State` for local view state.
- **State mutation:** Change state through explicit view-model methods and perform persistence or other side effects in those methods. Do not use `didSet`, `willSet`, or custom getter/setter accessors to mutate state or trigger side effects. Read-only computed presentation properties remain permitted.
- **Root view models:** State shared between several screens or throughout the application belongs to root view models. Their type names must end with the literal `RootViewModel` suffix (`{FeatureName}RootViewModel`), for example `ApplicationRootViewModel` or `ExaminationRootViewModel`.
- **Module communication:** Direct interaction between client module view models is prohibited: do not pass, store, or call another module's view model. Exchange data and update state only through closures carried in the next module's `FeatureArguments` and forwarded to its view-model initializer, such as `getIsActive`, `getAvailableRequestCount`, `getNeuralModelSettingsAvailability`, and `onNeuralModelSelected`.
- **Root-to-module communication:** Interaction between a root view model and a module view model must occur only through closures passed into the module view model's initializer. Use getter and callback closures for state access and updates, and observation closures returning cancellable subscriptions to preserve reactive UI updates; never inject the root view model instance into a module view model or let the module access it directly. `DependencyContainer` must not be used to bypass these closure boundaries.
- **View-model propagation:** `FeatureScreenView` / `FeatureBottomSheetView` owns the model received from the entry view through `@StateObject` and injects that same instance into its subtree with `.environmentObject`. Every descendant view obtains `FeatureViewModel` only through private `@EnvironmentObject`; never pass it through descendant constructors or store it as `@ObservedObject` or a plain property. The entry-view-to-presentation-view handoff is the required constructor-based ownership boundary.
- **View declarations:** Keep views limited to input/state properties, initializers, and declarative `body` or computed view properties. Do not declare `func` methods in any view, including rendering helpers, event handlers, or business logic. The only exception is mandatory protocol entry points in framework adapters, such as `UIViewRepresentable.makeUIView`, `updateUIView`, and `makeCoordinator`; these delegate behavior to the feature view model or an adapter/controller and contain no unrelated presentation helpers. Other methods belong in the feature's view model; action and lifecycle closures call those methods. Express layout through declarative properties or separate SwiftUI view types.
- **View-model method order:** Arrange public interaction methods in the order their controls appear from top to bottom on the screen or bottom sheet. Group methods by the corresponding visible section so that reading the public API indicates where each interaction occurs. Put initialization and lifecycle methods before the interaction groups, then private helpers after the public methods, following the same section order where applicable.
- **Environment privacy:** `@EnvironmentObject` properties are private, except `theme` when it implements the `DView` requirement. Declare that theme directly as `@EnvironmentObject var theme: DTheme` (public in public components), without a separate stored property or forwarding getter.
- **Presentation ownership:** A module's view model decides which parts of its UI are shown. Pass required data and closures into that view model, expose computed flags such as `isSpeechButtonVisible` and `isNeuralModelSettingsVisible`, and let `*ScreenView` branch only on its own view model. Do not read unrelated `@EnvironmentObject` values for these decisions.
- **Naming:** Prefix ultrasound domain models with `US`, database models with the `DB` suffix, and DTO models with `DTO`. Use the `D` prefix for foundational framework types such as `DDatabase`, `DTheme`, and `DHttpClient`, and for the application's shared module base `DModuleViewModel`. Feature and root view models follow their own naming rules. All types declared in `DoglyadSpeech`, including nested helper types, use the `DSpeech` prefix. Keep engine-specific speech files in `SpeechAnalyzer/`, `SFSpeechRecognizer/`, and `WhisperKit/`; keep shared types outside these folders. Keep transcript confidence and decoding span types in `DoglyadSpeech/Span/`.
- **Localization:** Follow the shared Localization rules above for backend ownership, permitted client strings, key names, suffixes, and catalog injection.
- **Neural module:** Shared types use `DNeural`; ultrasound-specific types, including nested helpers, use `DNeuralUltrasound` and live in `UltrasoundExamination/`. Keep `DNeuralUltrasoundModelFactory` at that folder's root, above its Foundation Models integration. Shared code must not depend on ultrasound field IDs, schemas, or catalogs. Keep `DNeuralGenerationParameters`, `DNeuralModelError`, and `DNeuralModelProtocol` at the module root. Keep the ultrasound model and foundation provider protocols in `UltrasoundExamination/Contract/`. Keep shared values and numeric vocabularies in semantic folders at the module level; keep ultrasound contracts, parsing, validation, localization, server implementations and DTOs under `UltrasoundExamination/`. Extensions of shared values that parse ultrasound fields belong inside that domain folder. Experimental candidates and historical legacy schemas used only by comparisons belong in `DoglyadTests/VoiceSupport/`. Both Foundation Models and server parsing implement `DNeuralUltrasoundModelProtocol`; the factory selects the implementation, and `DNeuralUltrasoundProposalProcessor` owns shared validation/reconciliation. Server HTTP stays in the application repository through `DNeuralUltrasoundServerTransportProtocol`.
- **Utilities and extensions:** The client `Utility` directory is for extensions, mock data and factories, view modifiers, and integration classes tightly coupled to external packages, such as the App Check provider factory and HTTP interceptor. Place these in `ios/Doglyad/Utility/`, using `Extension/` for extensions of framework and package types, `Mock/` for mock data and factories, `Modifier/` for view modifiers, and package-specific folders such as `AppCheck/` for integrations. Do not scatter these utilities across feature modules. Application managers retain their established folders under `ios/Doglyad/Application/`; `PermissionManager` and `ConnectionManager` belong in `ios/Doglyad/Application/Application/Manager/`.
- **Extension organization:** Group extensions by the extended type within their owning target. Keep extensions of the same class, struct, or other type together in one file and combine compatible members in a single extension block. Do not create separate files for individual extension methods or features; for example, `View.localization`, `View.paidBadge`, and `View.previewable` belong together in `ios/Doglyad/Utility/Extension/View.swift`.
- **Modules:** Keep reusable domain services and components in the local framework targets `DoglyadUI`, `DoglyadDatabase`, `DoglyadNetwork`, `DoglyadNeuralModel`, `DoglyadCamera`, and `DoglyadSpeech`. Client utilities and framework extensions follow the locations specified above.
- **External SPM dependencies:** RevenueCat, Firebase, Alamofire, swift-markdown-ui, SwiftMessages, SwiftUI-Shimmer, BottomSheet, WhisperKit, `DependencyInitializer`, `NestedObservableObject`, `Handler`, and `Router`. FluidAudio is used by the experimental Parakeet comparison in tests.
- **Enum branching:** Express behavior that depends on an enum with an exhaustive `switch` and no `default`, never with `==` or `!=`. Adding a case must produce compiler errors everywhere it is not handled. For non-frozen enums owned by an external SDK, handle every known case explicitly and use `@unknown default` only for future SDK cases; this exception does not apply to project-owned enums. This applies, for example, to visibility flags based on `SubscriptionFeatureAvailability`.

## Constraints

- Preserve camelCase fields in backend Pydantic models because they are the iOS API contract.
- Build client layout exclusively from `DoglyadUI` components, including loading shimmer, using SwiftUI for declarative composition.
- Use visual resources only through `DoglyadUI` or `ios/Doglyad/Assets.xcassets`; direct use of system or third-party framework resources is prohibited.
- Client module view models communicate only through closures in module arguments; root-to-module interaction uses only closures in the module view-model initializer.
- Use only `DoglyadNetwork` resources for client networking.
- Use only `DoglyadDatabase` resources for client persistence.
- Do not modify `ios/DoglyadNeuralModel/Resources/`, `ios/Config/`, `ios/Firebase/`, `backend/main/secrets/`, or `backend/inference/secrets/`. For local iOS preparation, `make init-ios-local` may update only `BASE_URL` in `ios/Config/Config.Local.xcconfig`.
- The main backend does not run inference and lives on a non-GPU VM. All model execution belongs in `backend/inference/`.
- Prompts, application localization, and templates live in the main backend, with only the explicitly listed bootstrap and iOS system localization exceptions on the client. The inference service receives final text and only performs generation.

## Commands

The `Makefile` contains all project commands. Common targets:

- `make venv` / `make pip-install` — create a Python 3.11 environment and install `backend/main/requirements.txt`.
- `make format` — run the iOS formatting pipeline and Ruff format for both backends.
- `make format-ios` / `make lint-ios` — apply or check SwiftFormat and the mandatory argument line breaks without modifying protected resource/configuration folders.
- `make init-ios-local` — update the local iOS `BASE_URL` with the `en0` address; see [init-ios-local](.codex/skills/init-ios-local/SKILL.md).
- `make build-ios-debug-local` / `make build-ios-debug-development` / `make build-ios-release-development` / `make build-ios-release-production` — build the matching Xcode scheme; override `IOS_DEST` to select another simulator.
- `make start-backend-main-development` / `make start-backend-main-production` — run the main backend with the matching environment profile.
- `make check-infrastructure` / `make update-infrastructure` — check or update all inventoried existing backend VMs through the central deployment script. Set `INFRASTRUCTURE_SCOPE=main` to select both main environments without contacting inference VMs; inference availability/routes are unverified in this mode. See `deploy/README.md`; `start-backend-*` builds from source and is not the deployed-fleet update path.
- `make start-backend-main-logs` / `make stop-backend-main` — follow logs or stop the main backend.
- `make start-backend-inference` / `make start-backend-inference-logs` / `make stop-backend-inference` — manage the inference stack **on a GPU VM**, not on a developer machine. The stack starts vLLM with `SERVED_MODEL_ID` and the adjacent inference service.
