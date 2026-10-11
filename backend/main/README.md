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

## Voice test scenarios

The `transcript` in each `voice_form.json` is a sample dictation, and `generation` contains its expected model proposals. You can dictate the whole sample or a fragment with the same evidence text. It is a deterministic fixture matcher, not a replacement speech parser.

Russian sample:

> Номер исследования 123. Пациент Иванов Иван Иванович. Пол мужчина. Дата рождения 15 января 1985 года. Рост 180 сантиметров. Вес 75 килограммов. Жалобы: боль в животе. Описание исследования: контуры печени ровные, эхогенность не изменена.

English sample:

> Examination number 123. Patient John Smith. Male. Date of birth January 15, 1985. Height 180 centimeters. Weight 75 kilograms. Complaints: abdominal pain. Examination description: liver contours are smooth, echogenicity is unchanged.

The fixtures affect server-side parsing only. If the iOS app selects Apple Foundation Models for on-device parsing, that operation does not reach this backend.
