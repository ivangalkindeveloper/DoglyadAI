# Doglyad — AI assistant for ultrasound examination analysis

Doglyad is an AI assistant that analyzes ultrasound images together with patient history and generates a medical report.

## Architecture

The backend is split into two independently deployable services: `backend/main` and `backend/inference`.

- **Main backend** (`backend/main/`) — Python, FastAPI, Docker. Runs on a **non-GPU VM** and never performs inference itself: it builds the prompt, selects the model, and routes the request. It also sends reports by email through SMTP.
- **Inference service** (`backend/inference/`) — Python, FastAPI, Docker. Runs on a **GPU VM** (one VM per model) beside local vLLM and the model. It validates App Check and generates the report.
- **iOS application** — SwiftUI, MVVM, SwiftData, Alamofire, MLX for on-device inference, Firebase, and RevenueCat for subscriptions.

A report-generation request follows this path:

```text
iOS ──► backend/main (non-GPU) ──► backend/inference + vLLM (model GPU VM)
```

App Check is validated **twice**: at the system entry point (`backend/main`) and again on the model machine (`backend/inference`). The `X-Firebase-AppCheck` header is forwarded unchanged, so both services validate the same token.

The main-backend check protects the public system entry point. The repeated check prevents direct access to a GPU VM that bypasses the main backend. Both VM groups are controlled by the developer.

Validation cannot be disabled: there is no flag or mode. The entire `/v1` router is protected in every environment.

Only configuration endpoints live outside `/v1`: `/application_config` and the three `ultrasound_examination_*` endpoints. They are intentionally open because the app reads them before it can authenticate, and the documents are public by nature—they previously lived in the public repository. Infrastructure also uses them for liveness checks.

### Environments

`ENVIRONMENT` (`development` or `production`) selects a directory under `backend/main/config/` and does nothing else. The application reads the same documents from this backend instead of the repository. Otherwise, pushing a new model to `master` could expose it to the app before the backend deployment knows about it, causing a physician to receive `400`. Both environments use the same inference route and token validation. A development-staging check is meaningful because it exercises the same code and path; only the model list, examination types, and application settings differ.

### Timeouts

Timeouts are strictly nested from outside to inside, with each wrapper wider than the operation it contains:

```text
iOS client                    300  application.json -> network.timeoutIntervalForRequest
INFERENCE_REQUEST_TIMEOUT     130  main backend waits for the GPU VM
VLLM_REQUEST_TIMEOUT          120  inference VM waits for its local engine
```

An inner timeout must be shorter than its outer timeout; otherwise the caller can terminate the connection while the wrapped generation is still running.

Every published model must have an entry in `backend/main/secrets/inference_endpoints.json` containing the URL of its GPU VM. A missing mapping is a configuration error.

## Code map

### `backend/main/` — main backend

| Path | Description |
|---|---|
| `backend/main/app/main.py` | FastAPI application, lifespan (configuration loading, shared `httpx.AsyncClient`, service initialization), protected `/v1` App Check router, adjacent public configuration router, and rate limiter |
| `backend/main/app/route/ultrasound_conclusion.py` | `POST /v1/ultrasound_conclusion`: accepts examination data, calls `ModelService`, forwards the App Check token, and returns a report |
| `backend/main/app/route/ultrasound_conclusion_send_email.py` | `POST /v1/ultrasound_conclusion_send_email`: sends a report through SMTP (`smtplib`) |
| `backend/main/app/route/application_config.py` | Four application configuration endpoints: `/application_config`, `/ultrasound_examination_types`, `/ultrasound_examination_neural_models`, and `/ultrasound_examination_contextual_strings`. They are **outside `/v1`** and do not use App Check. Files are returned as original text without a `response_model`; modeling the full configuration tree would create a second schema that could drift from JSON. |
| `backend/main/app/core/variables.py` | Environment variables through `pydantic_settings` (`Variables`): `ENVIRONMENT`, `FIREBASE_CREDENTIALS_PATH`, `EMAIL_*`, `INFERENCE_ENDPOINTS_PATH`, and timeouts, including values loaded from `backend/main/secrets/.env` |
| `backend/main/app/core/app_check.py` | Entry-point App Check validation: `APP_CHECK_HEADER`, `init_app_check`, and the `verify_app_check` dependency attached to `/v1`. It is unconditional; the backend cannot start without Firebase credentials. |
| `backend/main/app/core/config.py` | Startup configuration loading. Neural models and examination types are parsed into objects, while `SERVED_DOCUMENTS` are also retained as text for `resolve_config_document`. Includes model and title resolvers. |
| `backend/main/app/service/` | Inference abstraction: `ModelService` and `InferenceRequest` in `base.py`, `InferenceService` in `inference.py`. `create_model_service()` in `factory.py` creates the service once during lifespan and stores it in `app.state.model_service`; routes only call the ready service. |
| `backend/main/app/model/` | Pydantic models: `neural_model_settings.py`, `inference_response.py`, and the `ultrasound/` package for request, data, conclusion, email, scan photo, type, and neural-model models |
| `backend/main/secrets/inference_endpoints.json` | Manually maintained `modelId -> GPU VM URL` map, read from `INFERENCE_ENDPOINTS_PATH`, with one entry per VM. Never committed. |
| `backend/main/app/prompt/` | Prompt generation: `PromptFactory` in `base.py`, `ru.py` and `en.py` localizations, and `resolve_prompt_factory` in `__init__.py` |
| `backend/main/config/` | Environment-specific JSON documents (`development/`, `production/`): `application.json`, `ultrasound_examination_neural_models.json`, `ultrasound_examination_types.json`, and `ultrasound_examination_contextual_strings.json`. The backend loads them at startup and serves them through `app/route/application_config.py`. They are baked into the image by `backend/main/Dockerfile`. |
| `backend/main/docker-compose.yml` | Docker Compose reads `backend/main/secrets/.env` and a profile-specific `secrets/.env.<profile>` selected through `ENV_FILE`. Only `./secrets` and `./logs` are mounted; configuration is baked into the image. |

### `backend/inference/` — inference service

This service runs on a GPU VM, one VM per model. See [`backend/inference/README.md`](backend/inference/README.md) for the full deployment guide.

| Path | Description |
|---|---|
| `backend/inference/app/main.py` | FastAPI application, lifespan (`httpx.AsyncClient`, App Check, vLLM service), and the only `/v1` router protected entirely by App Check. The service has no unauthenticated endpoints. |
| `backend/inference/app/route/conclusion_generation.py` | `POST /v1/conclusion_generation`: accepts ready prompts and images and returns generated report text |
| `backend/inference/app/service/vllm.py` | `VLLMService`: calls local vLLM through the OpenAI-compatible `/v1/chat/completions` endpoint and checks `modelId` against `SERVED_MODEL_ID` |
| `backend/inference/app/core/app_check.py` | Second App Check validation on the model machine. `init_app_check` and `verify_app_check` protect `/v1`. Validation is **unconditional**: the service cannot start without Firebase credentials, and there is no bypass. |
| `backend/inference/app/core/variables.py` | `FIREBASE_CREDENTIALS_PATH`, `SERVED_MODEL_ID`, and `VLLM_*`. This service has no `ENVIRONMENT` because it has no environment-specific configuration documents. |
| `backend/inference/docker-compose.yml` | Two containers: `vllm` (model image and GPU) and `inference_backend` (the service). Start with `--env-file secrets/.env` through `make start-backend-inference`. |

### `ios/` — iOS application

| Path | Description |
|---|---|
| `ios/Doglyad/Application/Application/` | Entry point `Application.swift`, `ApplicationViewModel`, root views (`MainRootView`, `ErrorRootView`), and router (`DRouter`, `RouteType`) |
| `ios/Doglyad/Application/Component/` | Reusable application-level UI components that are not part of the design system |
| `ios/Doglyad/Application/Module/` | Screens and view models. Each module contains `*Screen.swift`, `*ScreenView.swift`, `*ViewModel.swift`, and `*Arguments.swift`. Modules include `Scan`, `ScanSpeech`, `Select`, `Conclusion`, `RecievedConclusion`, `History`, `Storage`, `Template`, `Settings`, `UserSettings`, `NeuralModel`, `Subscription`, `LimitExceeded`, `Share`, `OnBoarding`, `Permission`, `NewVersion`, `WebDocument`, and `About`. |
| `ios/Doglyad/Core/DependencyContainer.swift` | Dependency-injection container for repositories, managers, configuration, the neural model, the initial screen, and subscription state |
| `ios/Doglyad/Core/Initialization/` | Initialization through the `DependencyInitializer` package. `InitializationProcess` is filled by `StepSet` values in `stepsTier1…stepsTier5`, each with synchronous and asynchronous steps; `toContainer` produces the final `DependencyContainer`. |
| `ios/Doglyad/Core/Environment/` | `EnvironmentProtocol` and `EnvironmentType` for development and production configuration |
| `ios/Doglyad/Domain/` | Domain models: `Ultrasound/`, `Config/`, `Subscription/`, `NeuralModelSettings`, and `PatientGender` |
| `ios/Doglyad/Repository/` | Repository protocols and implementations for conclusions, models, shared data, RevenueCat subscriptions, templates, and user settings |
| `ios/Doglyad/Utility/` | Extensions, modifiers, and managers such as `PermissionManager` and `ConnectionManager` |
| `ios/Doglyad/Resources/Localizable.xcstrings` | Application localization catalog |
| `ios/DoglyadUI/` | Design system: `DTheme`, Montserrat fonts, and reusable components such as `DSegment`, `DCloseButton`, `DButtonCard`, and `DMessage` |
| `ios/DoglyadDatabase/` | SwiftData database: `DDatabase`, `*DB.swift` entities, and UserDefaults wrappers |
| `ios/DoglyadNetwork/` | Alamofire HTTP client: `DHttpClientProtocol`, `DHttpClient`, `DHttpHeader`, and `DHttpError` |
| `ios/DoglyadNeuralModel/` | ML model integrations using MLX and Foundation Models |
| `ios/DoglyadCamera/` | Camera implementation: `DCameraController` and `DCameraView` |
| `ios/DoglyadSpeech/` | Speech recognition: `DSpeechController` implementations and lexicon correction |
| `ios/Config/` | Build configuration. Development and production `.xcconfig` files define `ENVIRONMENT`, `BASE_URL`, and `REVENUECAT_API_KEY`. Xcode schemes select the matching configuration; files are never copied or swapped. |
| `ios/Firebase/` | Environment-specific Firebase configuration. A Run Script phase places the matching `GoogleService-Info.plist` in the bundle according to `$CONFIGURATION`; files are not committed. |

## Code style

### Python backend

- **Framework:** FastAPI with Pydantic models.
- **Typing:** Put `from __future__ import annotations` in every file and annotate all functions and values.
- **Naming:** Use snake_case for functions and variables, CamelCase for classes and Pydantic models, and camelCase for Pydantic fields shared with iOS.
- **Concurrency:** Use `async`/`await` for handlers and HTTP calls. Reuse the shared `httpx.AsyncClient` from application state.
- **Configuration:** Read environment values through `pydantic_settings` in `app/core/variables.py`, including values from `backend/main/secrets/.env`.
- **Dependencies:** Pin versions in `requirements.txt`.
- **Inference logs:** Never log request bodies because they contain patient data and images. Log only status, model ID, image count, and string lengths.
- **Inference route construction:** Build the inference path only in `create_model_service()` (`app/service/factory.py`). The same connection applies to all environments. Routes receive a ready `ModelService` from `app.state.model_service` and call it.

### Swift iOS

- **Initialization:** `DependencyInitializer` runs `InitializationProcess` through ordered `StepSet` values in `stepsTier1…stepsTier5`. Each set contains synchronous and asynchronous steps. `ApplicationViewModel.initialize()` starts the process, `toContainer` builds `DependencyContainer`, and SwiftUI Environment receives the container.
- **Concurrency:** Use Swift Concurrency (`async`/`await`, `Task`) and `@MainActor` for UI code.
- **Architecture:** Follow MVVM. A module contains `*Screen` (SwiftUI view and view-model creation), `*ScreenView` (pure view without logic), `*ViewModel` (`ObservableObject` with presentation logic), and `*Arguments` (module input). When a view model depends on `DependencyContainer`, pass the entire container rather than individual dependencies.
- **State:** Use `ObservableObject` and `@Published` for scalar state, `@NestedObservableObject` for nested observable controllers, `@StateObject` for view-model ownership, `@EnvironmentObject` for environment injection, `@ObservedObject` for externally owned controllers, and `@State` for local view state.
- **Module communication:** View models never communicate directly. Exchange data only through closures supplied when a module creates its view model, such as `getIsActive`, `getAvailableRequestCount`, `getNeuralModelSettingsAvailability`, and `onNeuralModelSelected`.
- **Presentation ownership:** A module's view model decides which parts of its UI are shown. Pass required data and closures into that view model, expose computed flags such as `isSpeechButtonVisible` and `isNeuralModelSettingsVisible`, and let `*ScreenView` branch only on its own view model. Do not read unrelated `@EnvironmentObject` values for these decisions.
- **Naming:** Prefix ultrasound domain models with `US`, database models with the `DB` suffix, and DTO models with `DTO`. Use the `D` prefix only for foundational types from custom modules such as `DDatabase`, `DTheme`, and `DHttpClient`.
- **Modules:** Keep reusable code in the local framework targets `DoglyadUI`, `DoglyadDatabase`, `DoglyadNetwork`, `DoglyadNeuralModel`, `DoglyadCamera`, and `DoglyadSpeech`.
- **External SPM dependencies:** RevenueCat, Firebase, MLX, swift-transformers, Alamofire, swift-markdown-ui, SwiftMessages, SwiftUI-Shimmer, BottomSheet, `DependencyInitializer`, `NestedObservableObject`, `Handler`, and `Router`.
- **Enum branching:** Express behavior that depends on an enum with an exhaustive `switch` and no `default`, never with `==` or `!=`. Adding a case must produce compiler errors everywhere it is not handled. This applies, for example, to visibility flags based on `SubscriptionFeatureAvailability`.

## Constraints

- Preserve camelCase fields in backend Pydantic models because they are the iOS API contract.
- Use only SwiftUI and `DoglyadUI` components for client layout.
- Use only `DoglyadNetwork` resources for client networking.
- Use only `DoglyadDatabase` resources for client persistence.
- Do not modify `ios/DoglyadNeuralModel/Resources/`, `ios/Config/`, `ios/Firebase/`, `backend/main/secrets/`, or `backend/inference/secrets/`.
- The main backend does not run inference and lives on a non-GPU VM. All model execution belongs in `backend/inference/`.
- Prompts, localization, and templates live only in the main backend. The inference service receives final text and only performs generation.

## Commands

The `Makefile` contains all project commands. Common targets:

- `make venv` / `make pip-install` — create a Python 3.11 environment and install `backend/main/requirements.txt`.
- `make format` — run SwiftFormat for iOS and Ruff format for both backends.
- `make init-ios-local` — update the local iOS `BASE_URL` with the `en0` address.
- `make build-ios-debug-local` / `make build-ios-debug-development` / `make build-ios-release-development` / `make build-ios-release-production` — build the matching Xcode scheme; override `IOS_DEST` to select another simulator.
- `make download-ios-examination-model` — download `mlx-community/Qwen2.5-1.5B-Instruct-4bit` into `DoglyadNeuralModel/Resources/`.
- `make start-backend-main-development` / `make start-backend-main-production` — run the main backend with the matching environment profile.
- `make start-backend-main-logs` / `make stop-backend-main` — follow logs or stop the main backend.
- `make start-backend-inference` / `make start-backend-inference-logs` / `make stop-backend-inference` — manage the inference stack **on a GPU VM**, not on a developer machine. The stack starts vLLM with `SERVED_MODEL_ID` and the adjacent inference service.
