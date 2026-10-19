# Main backend: local development

The main backend runs FastAPI through Uvicorn on port `8000`. VS Code launch profiles run it directly on the Mac using `debugpy`, with `--host 0.0.0.0` so a physical iPhone can connect over the local network.

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

`POST /v1/ultrasound/parse_dictation` accepts `selectedNeuralModelId` alongside `usExaminationTypeId` and `transcript`. It resolves that model through the same published model catalog as report generation. A missing selection uses the catalog's default model. `voice_form_parsing.json` contains the parsing token limit only; parsing keeps its own prompt, schema and temperature of zero. Audio stays on the client.

The SettingsAI screen and its entry cards are available independently of Pro. In iOS, `entitlement.settingsAI` applies only to report-generation controls: Markdown, temperature and token limit require an active Pro subscription with this entitlement available. Speech choices stay editable. Saving speech choices without Pro preserves stored report-generation preferences; generation uses the default report parameters until Pro access is available. Mapping `SettingsAIDB` to the domain trims speech identifiers and defaults missing, blank or unknown values to WhisperKit and server parsing without throwing.
