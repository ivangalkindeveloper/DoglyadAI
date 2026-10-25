# Main backend: local development

The main backend runs FastAPI through Uvicorn on port `8000`. VS Code launch profiles run it directly on the Mac using `debugpy`, with `--host 0.0.0.0` so a physical iPhone can connect over the local network.

Docker runs the backend as UID/GID `10001:10001`. `make start-backend-main-development` and `make start-backend-main-production` build the image, prepare mounted directory permissions with a temporary root helper, and start the backend. The helper preserves host file owners, grants the application group read access to credentials and write access to logs, and removes world access. Credentials remain mounted read-only. VS Code launches continue to run as the local user.

## Launch profiles

| VS Code profile | Configuration | Generation |
|---|---|---|
| `Backend: Development` | `config/development` | Real GPU inference |
| `Backend: Local Mock` | `config/development` | Local RU/EN fixtures |
| `Backend: Production` | `config/production` | Real GPU inference |

Each profile's prelaunch task merges the existing shared `secrets/.env` and selected `secrets/.env.development` or `secrets/.env.production` into the ignored `secrets/.env.running`. `Variables` reads process environment values; it does not load an environment file itself.

`ENVIRONMENT` selects configuration documents only. `MODEL_SERVICE_TYPE` independently selects `inference` or `mock`; the default is `inference`. The launch profiles set this value explicitly so switching back to Development or Production restores real inference.

To use mocks:

1. Stop the running backend instance so port `8000` is free.
2. Select `Backend: Local Mock` in VS Code's Run and Debug panel and start it.
3. Run the iOS app with `Doglyad-Debug-Local`. Run `make init-ios-local` again if the Mac's local IP address has changed.

Startup logs contain `Model service type: mock` and `Mock model service configured; GPU inference is not used`.

## What is mocked

`create_model_service()` creates one `MockNeuralModelService` at startup. Both generation routes keep their normal prompts, schemas, validation and response models. The internal `NeuralModelServiceRequest` identifies the operation and resolved language; this metadata is not added to the GPU HTTP request or client API.

- `POST /v1/ultrasound/generate_report` returns the selected language's demonstration report. Recommendations and description remarks follow the request flags. Photo remarks appear only when requested and photos are present: each uploaded photo receives two fixed points using its actual ID.
- `POST /v1/ultrasound/parse_dictation` returns fixture proposals whose evidence appears exactly once in the supplied transcript, ignoring case. The normal source validator still checks the result. Unmatched input receives no canned proposals; existing source-based validation can still extract explicitly labeled fields from that input.

Fixtures live in [`app/mock/`](app/mock/), with one `report.json` and `voice_form.json` per language. They are loaded and validated at startup; restart the backend after editing them. They are included in the main-backend image through the existing `COPY app` step.

The mock service does not call a GPU VM or read `INFERENCE_ENDPOINTS_PATH`. Firebase credentials and valid App Check tokens are still required. Configuration, localization, templates, rate limiting and report email delivery remain real, including SMTP.

Voice generation uses field-specific constraints for canonical gender and ISO date strings. Source validation independently verifies the actual date and gender, normalizes patient-name case, and retains valid, transcript-cited model proposals for clinical text. Differences from independently extracted source sections mark those proposals for physician review. Quoted evidence stays verbatim.

For dictation parsing and report generation, main resolves the selected examination's localized `contextualStrings` from its own configuration and includes them in the GPU prompt. Both system prompts include the same localized `medicalTermCorrectionPrompt`: the vocabulary helps repair misrecognized medical terms and supplies no patient findings. Numbers, units, negations, laterality, identities and dates must remain unchanged; ambiguous terms must be retained.

During dictation parsing, a nonblank clinical `value` with valid verbatim `evidence` is retained even when it changes words, measurements, negations or laterality; differences receive `questionable` accuracy for physician review. Source extraction fills clinical fields omitted by the model. `medicalTermCorrections` belongs only to the client's preprocessing corrector and never limits the model's proposed corrections. Report validation permits medical term repairs while retaining its checks on explicit measurements and misplaced sections.

Report prompts separate an explicitly dictated conclusion from findings. Templates supply structure, not evidence of normality. Content validation removes a misplaced conclusion or complaint section only when its complete text is independently supported by the corresponding section. It retains following findings and rejects changed or missing explicit length/volume measurements; unsupported section removal also fails validation. These checks supplement generation and do not establish the clinical accuracy of an image interpretation.

## Voice test scenarios

The `transcript` in each `voice_form.json` is a sample dictation, and `generation` contains its expected model proposals. You can dictate the whole sample or a fragment with the same evidence text. It is a deterministic fixture matcher, not a replacement speech parser.

Russian sample:

> Номер исследования 123. Пациент Иванов Иван Иванович. Пол мужчина. Дата рождения 15 января 1985 года. Рост 180 сантиметров. Вес 75 килограммов. Жалобы: боль в животе. Описание исследования: контуры печени ровные, эхогенность не изменена.

English sample:

> Examination number 123. Patient John Smith. Male. Date of birth January 15, 1985. Height 180 centimeters. Weight 75 kilograms. Complaints: abdominal pain. Examination description: liver contours are smooth, echogenicity is unchanged.

The fixtures affect server-side parsing only. If the iOS app selects Apple Foundation Models for on-device parsing, that operation does not reach this backend.

## AI settings and parser selection

The current client/report contract uses `settingsAI` (`SettingsAI`), including report generation parameters, `transcriberType` and `transcriptParserType`. The iOS `SettingsAIRepository` persists the complete settings as one encoded value. Transcription defaults to WhisperKit; the initial parser is FoundationModels when available for the current device and locale, otherwise server parsing. Subsequent runs honor the saved choice.

`POST /v1/ultrasound/parse_dictation` accepts `selectedNeuralModelId` alongside `usExaminationTypeId` and `transcript`. It resolves that model through the same published model catalog as report generation. A missing selection uses the catalog's default model. The server-only `server.json` contains the parsing token limit under `voice_form_parsing`; parsing keeps its own prompt, schema and temperature of zero. Audio stays on the client.

The SettingsAI screen and its entry cards are available independently of Pro. In iOS, `entitlement.settingsAI` applies only to report-generation controls: Markdown, temperature and token limit require an active Pro subscription with this entitlement available. Speech choices stay editable. Saving speech choices without Pro preserves stored report-generation preferences; generation uses the default report parameters until Pro access is available. Mapping `SettingsAIDB` to the domain trims speech identifiers and defaults missing, blank or unknown values to WhisperKit and server parsing without throwing.


## Application composition and dependencies

`app.main` creates a FastAPI application with `create_app()`. Every application gets its own settings and rate limiter. `MainLifespan` loads a complete `Configuration`, initializes App Check, creates one shared `httpx.AsyncClient`, selects the model service, and composes `MainContainer`. The client closes after shutdown and on any startup failure.

HTTP handlers receive services and the request language through FastAPI `Depends`. `ReportGenerationService`, `DictationParsingService`, `ConfigurationResponseService` and `ReportEmailService` own their respective operations. Their dependencies are passed through constructors; language, App Check token and request ID remain per-request method arguments. `ConfigurationLoader` returns data instead of publishing module-global dictionaries. `PromptFactory`, `ReportValidator` and `VoiceFormValidator` receive their configuration or localization explicitly.

## Server configuration

Report requests accept only `male` or `female` for `patientGender`, matching the iOS enum and voice parsing contract. Optional `patientHeight` (cm) and `patientWeight` (kg) accept finite positive JSON numbers or `null`; zero, negatives, booleans and numeric strings return `422` with the affected field location. No arbitrary upper medical bounds are imposed.

Each environment has `config/<environment>/server.json`, baked into the image alongside the application documents. This file is server-only and is never returned by configuration endpoints. Restart or redeploy after editing it. `Variables` supplies environment selection, paths, credentials, SMTP connection details and model-service selection. Operational timeouts are configured in JSON rather than `INFERENCE_REQUEST_TIMEOUT_SECONDS`.

- `endpoints`: the exact `/v1` paths, requests per minute per client IP, and maximum HTTP body sizes in bytes. Startup rejects missing or unknown paths. Rate counters are per application process; the deployment uses one Uvicorn worker.
- `inference`: HTTPX connect, read, write and pool timeouts plus an overall operation deadline. The 130-second operation deadline bounds the outgoing inference call and maps expiry to `504`. Inference overload remains `503` with `Retry-After`.
- `max_image_bytes`: maximum decoded bytes per Base64 image (4 MiB). Image count comes from `application.json` → `ultrasound.scanPhotoMaxNumber` (currently six). Invalid Base64 is rejected before generation.
- `voice_form_parsing.maxTokens`: generation token limit for voice parsing. The transcript length comes from the public `application.json` module configuration.
- `email`: SMTP socket timeout (15 seconds), attachment count, per-attachment bytes and total decoded attachment bytes. TLS verifies the SMTP server certificate and hostname. SMTP exceptions are logged by category without addresses or remote replies. Session shutdown errors do not turn an accepted send into a failed operation. SMTP acceptance does not establish delivery to the final mailbox or deduplicate separate client requests.

The report and email body limit is 40 MiB. Six images of up to 4 MiB occupy about 32 MiB after Base64 encoding, leaving roughly 8 MiB for text and JSON. All fields contribute to the actual UTF-8 body size, including JSON escaping. This body bound and the selected model's token/context capacity are separate from per-field character limits.

## Module configuration and input lengths

Both environments publish independent `scan`, `scanSpeech`, `templateAdd`, `templateEdit`, `readyMadeTemplateList`, `userSettings` and `settingsAI` sections in `application.json`. These sections belong to their modules and may gain other settings. `ApplicationModuleConfig` validates this subset without creating a second model for the complete application document. Every configured maximum is a required positive integer; there are no runtime fallbacks for missing module sections.

| Module | Maximum characters |
|---|---|
| `scan` | Examination number 64; patient name 256; height/weight input 6 each; complaints 4000; examination description 8000 |
| `scanSpeech` | Transcript 8000 |
| `templateAdd`, `templateEdit` | Independently configured name 120 and content 8000 |
| `readyMadeTemplateList` | Search input 200 |
| `userSettings` | Email input 254 |
| `settingsAI` | Temperature input 8; max-token input 4 |

Main checks examination strings, transcript, email recipient and selected template before model execution or SMTP. `TextLengthValidator` counts extended Unicode grapheme clusters through pinned `regex`, matching the client formatter's whole-character counting for combining marks and emoji. Overflows return `422 textTooLong` with safe `fields` locations, without truncating server input. Numeric API values retain their numeric constraints; their input-string limits apply in the editor. Generation accepts template content up to the larger of the two independent editor limits. Published ready-made templates must fit both editors, checked at startup.

iOS creates each controller with `DTextFieldMaxLengthFormatter` last and a length validator using its module configuration. Ordinary entry and `setText` obey the formatter. `restoreText` preserves saved drafts, templates, preferences and recognized speech, displaying validation errors when a newly lowered limit is exceeded. Draft snapshots retain the full source; automatic and manual dictation parsing validate the editor before running. Bootstrap/preview `ApplicationConfig.default` uses unbounded placeholders while the service is unavailable; successful server decoding requires all real module limits.

The unused `defaultPatientHeightCM` and `defaultPatientWeightKG` settings have been removed; new examinations still leave both fields empty. Configurations are baked into backend images: change the environment's JSON, deploy the backend and reload application configuration. No iOS rebuild is needed for changing the published limits.

`RequestBodyLimitMiddleware` checks both declared and actually received bytes before JSON parsing, including requests with chunked bodies or incorrect `Content-Length`. Oversized HTTP bodies or decoded images return `413`; excessive photo counts and invalid encodings return `422`. This protection works with a direct Uvicorn launch and does not require Caddy. Local VS Code and `make start-backend-main-*` launches use Uvicorn directly; the separate `deploy/` VM composition still includes Caddy.


## API error contract

See [ERRORS.md](ERRORS.md). Expected failures are classes in `app/error/`, with code, description and status defined in the class. `ApiErrorHandler` formats errors from services, validation and body-limit middleware. `ApiErrorMiddleware` catches unexpected failures before they escape to the ASGI server's logger. Responses contain `code`, `detail`, `requestId`, and optional validation `fields`; `requestId` matches `X-Request-ID`. The current iOS transport handles HTTP failure statuses and does not decode the former FastAPI error body.
